--!strict
--[=[
	EmployeePreviewPlaySystem: plays clips on a live character preview (EmployeePreviewSystem.live / outfit, in a
	WorldModel): its idle loop, the reveal crossfading into the idle, the menu reaction, the fidget and an emote item's
	loop. The clip each one plays comes from EmployeePreviewClipUtils. Split out of EmployeePreviewSystem (which still
	exposes these under the same names).

	@class EmployeePreviewPlaySystem
]=]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationPlayerEngineSystem =
	require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerEngineSystem)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local AnimationFidgetSystem = require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationFidgetSystem)
local EmployeePreviewClipUtils = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeePreviewClipUtils)

-- Seconds an emote preview rests on the idle between two plays.
local EMOTE_PAUSE = 1
-- The longest a reveal waits for its faces to load before it starts anyway.
local REVEAL_PRELOAD = 2
-- Seconds a menu reaction fades in; a click lands anywhere in the idle's loop, up to 29 degrees from the reaction's
-- first pose at a joint (measured 2026-10-30).
local REACTION_FADE = 0.25
-- Seconds a reaction blends into a showcase idle before it ends: it lands on the employee's own idle, up to 75 degrees
-- from the showcase idle's first pose at a joint (measured 2026-10-30).
local SHOWCASE_RETURN = 0.4
-- Seconds a reveal crossfades into a skin's own idle (owner, 2026-11-03: a fade, not a new reveal ending per skin). The
-- reveal lands on the employee's idle, up to 94 degrees at a joint from a showcase idle's first pose; over 0.5 s the
-- arms move at most 4.5 degrees a frame, calmer than the reveal itself (measured on Sheriff Prickles, 2026-11-03).
local REVEAL_FADE = 0.5

local EmployeePreviewPlaySystem = {
	EMOTE_PAUSE = EMOTE_PAUSE,
	REVEAL_FADE = REVEAL_FADE,
}

local function load(model: Model, key: string?): AnimationTrack?
	local def = if key ~= nil then AnimationRegistry.get(key) else nil
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid ~= nil then humanoid:FindFirstChildOfClass("Animator") else nil
	if def == nil or animator == nil then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = def.assetId
	return animator:LoadAnimation(animation)
end

--[=[
	Plays the idle loop (`idleOf`) on a live preview (call after it is parented into a WorldModel), over `fade` seconds
	(nil = at once). Returns the track, nil when there is nothing to play.
]=]
function EmployeePreviewPlaySystem.playIdle(
	model: Model,
	employee: string,
	skin: string?,
	fade: number?,
	idle: string?
): AnimationTrack?
	local track = load(model, EmployeePreviewClipUtils.idleOf(employee, skin, idle))
	if track == nil then
		return nil
	end
	track.Looped = true
	track:Play(fade or 0)
	return track
end

--[=[
	Plays the reveal (`revealOf`) once on a live preview, then its idle (`playIdle`, the skin's showcase idle when it
	has one). A reveal ends on the employee's own idle, so a skin's own idle takes over with a REVEAL_FADE crossfade
	before the reveal's end. Its props and faces come from the clip's markers (EmotePropSystem / EmoteEffectSystem
	tracking the model). Returns the stop (it cancels the reveal or the idle that followed), or nil when there is no
	reveal (the caller plays the idle instead).
]=]
function EmployeePreviewPlaySystem.playReveal(
	model: Model,
	employee: string,
	skin: string?,
	idleItem: string?
): (() -> ())?
	local reveal = load(model, EmployeePreviewClipUtils.revealOf(employee, skin))
	if reveal == nil then
		return nil
	end
	-- The idle holds until the faces the reveal swaps in are loaded (a first swap drew a blank white face for a
	-- moment, Studio probe 2026-10-29), at most REVEAL_PRELOAD seconds.
	local idle = EmployeePreviewPlaySystem.playIdle(model, employee, skin, nil, idleItem)
	local stopped = false
	local started = false
	local handedOver = false
	local connection = reveal.Stopped:Connect(function()
		if not stopped and not handedOver and model.Parent ~= nil then
			idle = EmployeePreviewPlaySystem.playIdle(model, employee, skin, nil, idleItem)
		end
	end)
	-- A skin's own idle: crossfade into it before the reveal ends (the reveal ends on the employee's idle).
	local fading: RBXScriptConnection? = nil
	if EmployeePreviewClipUtils.idleOf(employee, skin, idleItem) ~= EmployeePreviewClipUtils.idleOf(employee, nil) then
		fading = RunService.Heartbeat:Connect(function()
			if not started or reveal.Length == 0 or reveal.TimePosition < reveal.Length - REVEAL_FADE then
				return
			end
			local waiting = fading
			if waiting ~= nil then
				waiting:Disconnect()
			end
			handedOver = true
			idle = EmployeePreviewPlaySystem.playIdle(model, employee, skin, REVEAL_FADE, idleItem)
			reveal:Stop(REVEAL_FADE)
		end)
	end
	local function start()
		if stopped or started or model.Parent == nil then
			return
		end
		started = true
		local holding = idle
		if holding ~= nil then
			holding:Stop(0)
			idle = nil
		end
		reveal:Play(0)
	end
	local faces = model:FindFirstChild(EmployeeConstants.FACES_FOLDER)
	if faces ~= nil then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ faces })
			end)
			start()
		end)
		task.delay(REVEAL_PRELOAD, start)
	else
		start()
	end
	return function()
		stopped = true
		connection:Disconnect()
		local waiting = fading
		if waiting ~= nil then
			waiting:Disconnect()
		end
		reveal:Stop(0)
		local settled = idle
		if settled ~= nil then
			settled:Stop(0)
		end
	end
end

--[=[
	Plays the reaction (`reactionOf`) once on a live preview that is playing its idle, then that idle again. The idle
	stops for it, so a showcase idle's props stow with the idle's track and come back with it (owner, 2026-10-29: a
	Legendary skin reacts with its props hidden). Returns the stop (it fades the reaction out and leaves the idle, so a
	new reaction takes over from a pose, never from nothing), or nil when there is no reaction.
]=]
function EmployeePreviewPlaySystem.playReaction(
	model: Model,
	employee: string,
	skin: string?,
	idle: string?
): (() -> ())?
	local reaction = load(model, EmployeePreviewClipUtils.reactionOf(employee))
	if reaction == nil then
		return nil
	end
	local idleKey = EmployeePreviewClipUtils.idleOf(employee, skin, idle)
	local idleDef = if idleKey ~= nil then AnimationRegistry.get(idleKey) else nil
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid ~= nil then humanoid:FindFirstChildOfClass("Animator") else nil
	local stopped = false
	local handedOver = false
	local connection = reaction.Stopped:Connect(function()
		if not stopped and not handedOver and model.Parent ~= nil then
			EmployeePreviewPlaySystem.playIdle(model, employee, skin, nil, idle)
		end
	end)
	local returning: RBXScriptConnection? = nil
	if idleKey ~= EmployeePreviewClipUtils.idleOf(employee, nil) then
		returning = RunService.Heartbeat:Connect(function()
			if reaction.Length == 0 or reaction.TimePosition < reaction.Length - SHOWCASE_RETURN then
				return
			end
			local waiting = returning
			if waiting ~= nil then
				waiting:Disconnect()
			end
			handedOver = true
			EmployeePreviewPlaySystem.playIdle(model, employee, skin, SHOWCASE_RETURN, idle)
			reaction:Stop(SHOWCASE_RETURN)
		end)
	end
	-- The click lands anywhere in the idle's loop, so the reaction fades in over it; it covers the whole body, so the
	-- idle can stop unseen once it is in. The reaction's last pose is the idle's first, which is where the idle resumes.
	local covering: RBXScriptConnection? = nil
	covering = RunService.Heartbeat:Connect(function()
		if reaction.WeightCurrent < 1 then
			return
		end
		local waiting = covering
		if waiting ~= nil then
			waiting:Disconnect()
		end
		if idleDef ~= nil and animator ~= nil then
			for _, track in animator:GetPlayingAnimationTracks() do
				if track.Animation.AnimationId == idleDef.assetId then
					track:Stop(0)
				end
			end
		end
	end)
	reaction:Play(REACTION_FADE)
	return function()
		stopped = true
		connection:Disconnect()
		local waiting = covering
		if waiting ~= nil then
			waiting:Disconnect()
		end
		local handing = returning
		if handing ~= nil then
			handing:Disconnect()
		end
		reaction:Stop(REACTION_FADE)
	end
end

--[=[
	Runs the fidget (`fidgetOf`) on a live preview, the same wait as in the world, held off while a reveal or another
	Action clip plays. Returns the stop, or nil when it has no fidget.
]=]
function EmployeePreviewPlaySystem.playFidgets(
	model: Model,
	employee: string,
	skin: string?,
	idle: string?
): (() -> ())?
	local clip = EmployeePreviewClipUtils.fidgetOf(employee, skin, idle)
	local def = if clip ~= nil then AnimationRegistry.get(clip) else nil
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid ~= nil then humanoid:FindFirstChildOfClass("Animator") else nil
	if clip == nil or def == nil or animator == nil then
		return nil
	end
	local player = AnimationPlayerEngineSystem.forAnimator(animator)
	-- Loaded up front: a clip fetched at its first play would land late in the idle's loop.
	player:warm(clip)
	local fidget = AnimationFidgetSystem.new(player, { clips = { clip } })
	local own = { def.assetId }
	local idleKey = EmployeePreviewClipUtils.idleOf(employee, skin, idle)
	local idleDef = if idleKey ~= nil then AnimationRegistry.get(idleKey) else nil
	local idleAsset = if idleDef ~= nil then idleDef.assetId else nil
	local connection = RunService.Heartbeat:Connect(function()
		local tracks = animator:GetPlayingAnimationTracks()
		fidget:update(os.clock(), {
			pose = "idle",
			blocked = AnimationFidgetSystem.actionPlaying(tracks, own),
			idlePhase = AnimationFidgetSystem.loopTime(tracks, idleAsset),
		})
	end)
	return function()
		connection:Disconnect()
		fidget:destroy()
	end
end

--[=[
	Loops an emote item's clip on a live preview (owner, 2026-10-29): the emote, EMOTE_PAUSE seconds of the idle, the
	emote again. Its props and faces come from the clip's markers (EmotePropSystem / EmoteEffectSystem tracking the
	model). Returns the stop, or nil when the emote has no clip (the caller plays the idle instead).
]=]
function EmployeePreviewPlaySystem.playEmote(model: Model, employee: string, skin: string?, itemId: string): (() -> ())?
	local emote = load(model, EmployeePreviewClipUtils.emoteOf(itemId))
	if emote == nil then
		return nil
	end
	local idle = EmployeePreviewPlaySystem.playIdle(model, employee, skin)
	local stopped = false
	local again: thread? = nil
	local connection = emote.Stopped:Connect(function()
		if not stopped then
			again = task.delay(EMOTE_PAUSE, function()
				if not stopped and model.Parent ~= nil then
					emote:Play()
				end
			end)
		end
	end)
	emote:Play()
	return function()
		stopped = true
		connection:Disconnect()
		local pending = again
		if pending ~= nil then
			task.cancel(pending)
		end
		emote:Stop(0)
		if idle ~= nil then
			idle:Stop(0)
		end
	end
end

return EmployeePreviewPlaySystem
