--!strict
--[=[
	AnimationFidgetSystem: the rare extra move a character does after standing still for a while (owner, 2026-10-29:
	8 to 15 s, in the world and in menu previews, and a Gloom nearby does not stop it). A pure state core like
	AnimationLocomotionSystem, driven by `update`; it keeps out of that core, which animates locomotion and nothing else.

	The wait starts when the pose is `idle` and nothing blocks it. Any other pose or a block resets it and stops a clip
	already playing. After a clip ends the wait starts again. It never plays the same clip twice in a row when it has
	more than one.

	Each clip leaves the idle's first pose and lands back on the pose the idle has reached when it ends, so a due clip
	waits for the idle to come round (`idlePhase` wrapping). Anywhere else in the loop the two are up to 28 degrees
	apart at a joint, more than a fade can hide (measured 2026-10-30). The idle lasts 3 to 4 seconds, so the wait is
	lost in the 8 to 15 s window. With no `idlePhase` (the idle cannot be seen) a clip plays at once.

	`actionPlaying` is the block every caller shares: a playing Action clip (an emote, an action, a reveal) that is not
	one of the fidgets themselves.

	@class AnimationFidgetSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationPlayerSystem = require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerSystem)
local AnimationLocomotionSystem = require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionSystem)

type PosePlayer = AnimationLocomotionSystem.PosePlayer

local IDLE_POSE = "idle"
local MIN_DELAY = 8
local MAX_DELAY = 15
-- Seconds a fidget fades in and out; short, so a move answers at once.
local FADE = 0.15

local ACTION_PRIORITIES: { [Enum.AnimationPriority]: boolean } = {
	[Enum.AnimationPriority.Action] = true,
	[Enum.AnimationPriority.Action2] = true,
	[Enum.AnimationPriority.Action3] = true,
	[Enum.AnimationPriority.Action4] = true,
}

export type Config = {
	-- AnimationRegistry keys; empty = never fidgets.
	clips: { string },
	minDelay: number?,
	maxDelay: number?,
	random: Random?,
}

export type State = {
	pose: string?,
	blocked: boolean,
	-- Seconds into the idle's loop (`loopTime`).
	idlePhase: number?,
}

export type AnimationFidgetSystem = {
	update: (self: AnimationFidgetSystem, now: number, state: State) -> (),
	destroy: (self: AnimationFidgetSystem) -> (),
}

local AnimationFidgetSystem = {
	FADE = FADE,
}

--[=[
	How far the playing clip `assetId` is into its loop, nil when it is not playing.
	@param tracks { AnimationTrack } -- an Animator's GetPlayingAnimationTracks()
	@param assetId string?
	@return number?
]=]
function AnimationFidgetSystem.loopTime(tracks: { AnimationTrack }, assetId: string?): number?
	for _, track in tracks do
		if track.IsPlaying and track.Animation.AnimationId == assetId then
			return track.TimePosition
		end
	end
	return nil
end

--[=[
	True when one of `tracks` is a playing Action clip that is not one of `own` (the fidgets' asset ids).
	@param tracks { AnimationTrack } -- an Animator's GetPlayingAnimationTracks()
	@param own { string }
	@return boolean
]=]
function AnimationFidgetSystem.actionPlaying(tracks: { AnimationTrack }, own: { string }): boolean
	for _, track in tracks do
		if
			track.IsPlaying
			and ACTION_PRIORITIES[track.Priority] == true
			and table.find(own, track.Animation.AnimationId) == nil
		then
			return true
		end
	end
	return false
end

function AnimationFidgetSystem.new(player: PosePlayer, config: Config): AnimationFidgetSystem
	local clips = config.clips
	local minDelay = config.minDelay or MIN_DELAY
	local maxDelay = config.maxDelay or MAX_DELAY
	local random = config.random or Random.new()

	local dueAt: number? = nil
	local handle: AnimationPlayerSystem.PlayHandle? = nil
	local lastClip: string? = nil
	local lastPhase: number? = nil
	local destroyed = false

	local function stopClip()
		local playing = handle
		if playing ~= nil then
			playing:stop(FADE)
			handle = nil
		end
	end

	-- A clip other than the last one, when there is a choice.
	local function pick(): string?
		local choices: { string } = {}
		for _, clip in clips do
			if clip ~= lastClip then
				table.insert(choices, clip)
			end
		end
		if #choices == 0 then
			return clips[1]
		end
		return choices[random:NextInteger(1, #choices)]
	end

	local self: AnimationFidgetSystem = {
		update = function(_self: AnimationFidgetSystem, now: number, state: State)
			if destroyed then
				return
			end
			if state.pose ~= IDLE_POSE or state.blocked then
				stopClip()
				dueAt = nil
				lastPhase = nil
				return
			end
			local phase = state.idlePhase
			local previousPhase = lastPhase
			lastPhase = phase
			local playing = handle
			if playing ~= nil then
				if playing:isPlaying() then
					return
				end
				handle = nil
			end
			local due = dueAt
			if due == nil then
				dueAt = now + random:NextNumber(minDelay, maxDelay)
				return
			end
			if now < due then
				return
			end
			if phase ~= nil and (previousPhase == nil or phase >= previousPhase) then
				return
			end
			dueAt = nil
			local clip = pick()
			if clip ~= nil then
				lastClip = clip
				handle = player:play(clip, { fadeTime = FADE })
			end
		end,

		destroy = function(_self: AnimationFidgetSystem)
			destroyed = true
			stopClip()
		end,
	}
	return self
end

return AnimationFidgetSystem
