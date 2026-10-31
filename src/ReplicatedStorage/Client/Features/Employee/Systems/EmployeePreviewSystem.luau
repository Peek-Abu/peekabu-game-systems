--!strict
--[=[
	EmployeePreviewSystem: the models the character screens show in ViewportFrames (Inventory, the first-join pick,
	later the Shop and reveals): any employee in any skin, built on the client from the art in ReplicatedStorage and
	dressed by the same EmployeeSkinSystem the server dresses real characters with, so a preview never drifts.

	- `static(employee, skin, source, pose?, style?)`: posed once and frozen (EmployeePortraitSystem.build): every part
	  anchored, no Animator, no scripts. The engine renders it once: cards and grids.
	- `live(employee, skin, source, style?)`: the dressed model with its root held and the body free, an Animator, no
	  scripts: put it in a WorldModel and `playIdle` it. At most LIVE_CAP exist at once (the hero and one hovered
	  card); `live` returns nil past the cap. `release` destroys one and frees its slot at once (destroying it alone
	  frees the slot a frame later).
	- `skin` is an EmployeeRegistry skin key (nil = the default look); an unknown one falls back to the default.
	  `style` is its colour style (nil = 1; clamped to one the skin has).
	- `outfit(outfit, source, character, live, pose?)`: a whole player's look (CosmeticOutfitRules): a clone of
	  `character` (your own, live one) when it is that employee in that skin, so everything the server put on it
	  comes along (the rank lanyard and badge, the vacuum pack), else the dressed template; then the outfit's vacuum
	  goes on the pack (VacuumPreviewSystem.swap). Live (and its second result true) when asked and a slot is free,
	  else posed and frozen like `static`.

	@class EmployeePreviewSystem
]=]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EmployeeShared = ReplicatedStorage.Shared.Features.Employee
local AnimationPlayerEngineSystem =
	require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerEngineSystem)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local EmployeeConstants = require(EmployeeShared.Data.EmployeeConstants)
local EmployeePoseRegistry = require(EmployeeShared.Data.EmployeePoseRegistry)
local EmployeeRegistry = require(EmployeeShared.Data.EmployeeRegistry)
local EmployeeSkinRules = require(EmployeeShared.Rules.EmployeeSkinRules)
local EmployeeSkinSystem = require(EmployeeShared.Systems.EmployeeSkinSystem)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local VacuumSkinRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumSkinRules)
local AnimationFidgetSystem = require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationFidgetSystem)
local EmployeePortraitSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePortraitSystem)
local EmployeeLanyardSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeLanyardSystem)
local VacuumPreviewSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumPreviewSystem)

local LIVE_CAP = 2
-- Seconds an emote preview rests on the idle between two plays.
local EMOTE_PAUSE = 1
-- The longest a reveal waits for its faces to load before it starts anyway.
local REVEAL_PRELOAD = 2
-- Seconds a menu reaction fades in; a click lands anywhere in the idle's loop, up to 29 degrees from the reaction's
-- first pose at a joint (measured 2026-10-30).
local REACTION_FADE = 0.25

local EmployeePreviewSystem = {
	LIVE_CAP = LIVE_CAP,
	EMOTE_PAUSE = EMOTE_PAUSE,
}

local live: { [Model]: RBXScriptConnection } = {}
local liveCount = 0

local function resolve(root: Instance, path: { string }): Instance?
	local current: Instance? = root
	for _, name in path do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

-- A dressed clone of the employee's art (scripts removed) in colour style `style` (nil = 1), or nil.
local function dressed(employee: string, skin: string?, source: Instance, style: number?): Model?
	local def = EmployeeRegistry.get(employee)
	if def == nil then
		return nil
	end
	local template = resolve(source, def.templatePath)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	model:SetAttribute(EmployeeConstants.NAME_ATTRIBUTE, def.name)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local look = EmployeeSkinRules.select(def, skin)
	if look ~= nil then
		-- The outfit is fitted in the style, as the server dresses a real character.
		EmployeeSkinSystem.apply(
			model,
			look,
			resolve(source, EmployeeConstants.ACCESSORIES_PATH),
			style,
			resolve(source, EmployeeConstants.OUTFITS_PATH)
		)
	end
	EmployeeLanyardSystem.attachPreview(model)
	return model
end

function EmployeePreviewSystem.static(
	employee: string,
	skin: string?,
	source: Instance,
	pose: EmployeePoseRegistry.PoseDef?,
	style: number?
): Model?
	local model = dressed(employee, skin, source, style)
	if model == nil then
		return nil
	end
	local copy = EmployeePortraitSystem.build(model, pose)
	model:Destroy()
	return copy
end

-- Gives back `model`'s live slot (once).
local function free(model: Model)
	local connection: RBXScriptConnection? = live[model]
	if connection then
		connection:Disconnect()
		live[model] = nil
		liveCount -= 1
	end
end

-- Readies `model` to animate in a WorldModel (root held, body free, an Animator) and takes a live slot.
local function makeLive(model: Model): Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid:FindFirstChildOfClass("Animator") == nil then
		Instance.new("Animator").Parent = humanoid
	end
	liveCount += 1
	-- A backstop for a live preview destroyed without `release` (its slot frees when the deferred signal runs).
	live[model] = model.Destroying:Connect(function()
		free(model)
	end)
	return model
end

--[=[
	Destroys a live preview and frees its slot at once. Destroying alone frees it only when the deferred Destroying
	signal runs, a frame later, so a viewport rebuilding in the same frame (a colour style chip) got the frozen copy.
	Safe for a model that is not live, or released twice.
]=]
function EmployeePreviewSystem.release(model: Model)
	free(model)
	model:Destroy()
end

function EmployeePreviewSystem.live(employee: string, skin: string?, source: Instance, style: number?): Model?
	if liveCount >= LIVE_CAP then
		return nil
	end
	local model = dressed(employee, skin, source, style)
	return if model ~= nil then makeLive(model) else nil
end

-- A copy of a live character for a preview: scripts, tools and overhead labels left out.
local function cloneCharacter(character: Model): Model
	-- A player's character is not Archivable; it is made so just for the copy.
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	for _, descendant in copy:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Tool")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("ForceField")
		then
			descendant:Destroy()
		end
	end
	return copy
end

function EmployeePreviewSystem.outfit(
	outfit: CosmeticTypes.Outfit,
	source: Instance,
	character: Model?,
	wantLive: boolean,
	pose: EmployeePoseRegistry.PoseDef?
): (Model?, boolean)
	local skinKey = CosmeticRegistry.keyOf(outfit.look.skin)
	local def = EmployeeRegistry.get(outfit.employee)
	local skin = if def ~= nil then EmployeeSkinRules.select(def, skinKey) else nil
	local style = if skin ~= nil then EmployeeSkinRules.styleIndex(skin, outfit.look.style) else 1
	local model: Model? = nil
	-- Your own character only when it wears this employee, skin and colour style (the server stamps all three).
	if
		character ~= nil
		and character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) == outfit.employee
		and character:GetAttribute(EmployeeConstants.SKIN_ATTRIBUTE) == skinKey
		and (character:GetAttribute(EmployeeConstants.STYLE_ATTRIBUTE) or 1) == style
	then
		model = cloneCharacter(character)
	end
	if model == nil then
		model = dressed(outfit.employee, skinKey, source, style)
	end
	if model == nil then
		return nil, false
	end
	VacuumPreviewSystem.swap(model, VacuumSkinRules.select(CosmeticRegistry.keyOf(outfit.vacuum)), source)
	if wantLive and liveCount < LIVE_CAP then
		return makeLive(model), true
	end
	local copy = EmployeePortraitSystem.build(model, pose, true)
	model:Destroy()
	return copy, false
end

--[=[
	The animation registry key of the idle loop a preview plays: the skin's own showcase idle when it has one
	(EmployeeRegistry `showcaseIdle`), else the employee's idle (nil = no own locomotion).
]=]
function EmployeePreviewSystem.idleOf(employee: string, skin: string?): string?
	local def = EmployeeRegistry.get(employee)
	if def == nil then
		return nil
	end
	local look = if skin ~= nil then def.skins[skin] else nil
	local showcase = if look ~= nil then look.showcaseIdle else nil
	if showcase ~= nil then
		return showcase
	end
	local locomotion = def.locomotion
	return if locomotion ~= nil then locomotion.idle else nil
end

--[=[
	The animation registry key of the fidget a preview plays: the employee's, belonging to its idle (owner, 2026-10-29);
	nil when it has none, or the skin's showcase idle holds props the fidget does not know about.
]=]
function EmployeePreviewSystem.fidgetOf(employee: string, skin: string?): string?
	local def = EmployeeRegistry.get(employee)
	if def == nil then
		return nil
	end
	local look = if skin ~= nil then def.skins[skin] else nil
	if look ~= nil and look.showcaseIdle ~= nil then
		return nil
	end
	local locomotion = def.locomotion
	return if locomotion ~= nil then locomotion.fidget else nil
end

--[=[
	The animation registry key of the reveal the reveal screen plays for `employee` in `skin` (nil = a hire): the
	skin's own unlock reveal, else the employee's hire reveal worn in that skin; nil when there is none (its idle only).
]=]
function EmployeePreviewSystem.revealOf(employee: string, skin: string?): string?
	local def = EmployeeRegistry.get(employee)
	if def == nil then
		return nil
	end
	local look = if skin ~= nil then def.skins[skin] else nil
	local own = if look ~= nil then look.unlockReveal else nil
	return own or def.hireReveal
end

--[=[
	The animation registry key of the reaction a menu hero plays when clicked (EmployeeRegistry `selectReaction`); nil
	when it has none.
]=]
function EmployeePreviewSystem.reactionOf(employee: string): string?
	local def = EmployeeRegistry.get(employee)
	return if def ~= nil then def.selectReaction else nil
end

--[=[
	The animation registry key of the clip an emote item (a CosmeticRegistry id) loops in a preview; nil when the id is
	not an emote or its clip is not made yet.
]=]
function EmployeePreviewSystem.emoteOf(itemId: string): string?
	local item = CosmeticRegistry.get(itemId)
	if item == nil or item.kind ~= "emote" then
		return nil
	end
	local key = "emote:" .. itemId
	return if AnimationRegistry.get(key) ~= nil then key else nil
end

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
	Plays the idle loop (`idleOf`) on a live preview (call after it is parented into a WorldModel). Returns the track,
	nil when there is nothing to play.
]=]
function EmployeePreviewSystem.playIdle(model: Model, employee: string, skin: string?): AnimationTrack?
	local track = load(model, EmployeePreviewSystem.idleOf(employee, skin))
	if track == nil then
		return nil
	end
	track.Looped = true
	track:Play(0)
	return track
end

--[=[
	Plays the reveal (`revealOf`) once on a live preview, then its idle (`playIdle`, the skin's showcase idle when it
	has one). Its props and faces come from the clip's markers (EmotePropSystem / EmoteEffectSystem tracking the
	model). Returns the stop (it cancels the reveal or the idle that followed), or nil when there is no reveal (the
	caller plays the idle instead).
]=]
function EmployeePreviewSystem.playReveal(model: Model, employee: string, skin: string?): (() -> ())?
	local reveal = load(model, EmployeePreviewSystem.revealOf(employee, skin))
	if reveal == nil then
		return nil
	end
	-- The idle holds until the faces the reveal swaps in are loaded (a first swap drew a blank white face for a
	-- moment, Studio probe 2026-10-29), at most REVEAL_PRELOAD seconds.
	local idle = EmployeePreviewSystem.playIdle(model, employee, skin)
	local stopped = false
	local started = false
	local connection = reveal.Stopped:Connect(function()
		if not stopped and model.Parent ~= nil then
			idle = EmployeePreviewSystem.playIdle(model, employee, skin)
		end
	end)
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
function EmployeePreviewSystem.playReaction(model: Model, employee: string, skin: string?): (() -> ())?
	local reaction = load(model, EmployeePreviewSystem.reactionOf(employee))
	if reaction == nil then
		return nil
	end
	local idleKey = EmployeePreviewSystem.idleOf(employee, skin)
	local idleDef = if idleKey ~= nil then AnimationRegistry.get(idleKey) else nil
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid ~= nil then humanoid:FindFirstChildOfClass("Animator") else nil
	local stopped = false
	local connection = reaction.Stopped:Connect(function()
		if not stopped and model.Parent ~= nil then
			EmployeePreviewSystem.playIdle(model, employee, skin)
		end
	end)
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
		reaction:Stop(REACTION_FADE)
	end
end

--[=[
	Runs the fidget (`fidgetOf`) on a live preview, the same wait as in the world, held off while a reveal or another
	Action clip plays. Returns the stop, or nil when it has no fidget.
]=]
function EmployeePreviewSystem.playFidgets(model: Model, employee: string, skin: string?): (() -> ())?
	local clip = EmployeePreviewSystem.fidgetOf(employee, skin)
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
	local idleKey = EmployeePreviewSystem.idleOf(employee, skin)
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
function EmployeePreviewSystem.playEmote(model: Model, employee: string, skin: string?, itemId: string): (() -> ())?
	local emote = load(model, EmployeePreviewSystem.emoteOf(itemId))
	if emote == nil then
		return nil
	end
	local idle = EmployeePreviewSystem.playIdle(model, employee, skin)
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

function EmployeePreviewSystem.liveCount(): number
	return liveCount
end

-- Forgets every live slot (between specs).
function EmployeePreviewSystem.reset()
	for _, connection in live do
		connection:Disconnect()
	end
	table.clear(live)
	liveCount = 0
end

return EmployeePreviewSystem
