--!strict
--[=[
	AnimationLocomotionSystem: the pure state→pose core that replaces the forked Roblox `Animate` script
	(Phase 6 spec, Decision 3). `AnimationLocomotionHumanoidSystem` (beside this file) is the thin adapter, bound
	to the client-built rig by ReplicationServiceClient: it forwards Humanoid state events
	(with timestamps) into `handleEvent` and everything else — which pose, which fade, which speed scale,
	the jump window, the kill switch, the override seam — lives here, where it is specced against a fake
	AnimationPlayerSystem.

	What the old fork did that this deliberately does NOT: weighted random sets, chat `/e` hooks,
	tool animations, footstep/equipment sound wiring, dodge input, camera FOV. Each belongs to its
	own phase; this module animates locomotion, full stop.

	The Movement/Traversal phase extends this through `setPoseOverride`/`clearPoseOverride` (a
	parkour state pins its own registry pose; state-driven poses resume on clear) — the seam that
	replaces "edit the 1601-line script".

	@class AnimationLocomotionSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationPlayerSystem = require(ReplicatedStorage.Shared.Features.Animation.Systems.AnimationPlayerSystem)

--[=[
	The slice of AnimationPlayerSystem this module needs (structural, so specs fake three functions, not
	seven).
	@interface PosePlayer
]=]
export type PosePlayer = {
	play: (
		self: PosePlayer,
		id: string,
		opts: AnimationPlayerSystem.PlayOpts?
	) -> (AnimationPlayerSystem.PlayHandle?, string?),
	stop: (self: PosePlayer, id: string, fadeTime: number?) -> boolean,
	stopAll: (self: PosePlayer, fadeTime: number?) -> (),
}

--[=[
	Tuning knobs, all defaulted — the V5 feel checkpoint's surface. Scales are divisors: a pose's
	track speed is `moveSpeed / scale`, the old fork's convention.
	@interface Config
]=]
export type Config = {
	walkRunThreshold: number?,
	walkScale: number?,
	runScale: number?,
	climbScale: number?,
	swimScale: number?,
	jumpDuration: number?,
	-- Optional clamp on the walk / run play rate (puppets: 0.7-1.4, spec §6.8). Unset = unclamped (the owner).
	minRate: number?,
	maxRate: number?,
}

export type LocomotionEvent =
	"running"
	| "jumping"
	| "freefall"
	| "climbing"
	| "swimming"
	| "seated"
	| "died"
	| "gettingUp"
	| "platformStanding"

export type AnimationLocomotionSystem = {
	handleEvent: (self: AnimationLocomotionSystem, event: LocomotionEvent, speed: number?, now: number) -> (),
	update: (self: AnimationLocomotionSystem, now: number) -> (),
	currentPose: (self: AnimationLocomotionSystem) -> string?,
	setEnabled: (self: AnimationLocomotionSystem, enabled: boolean) -> (),
	isEnabled: (self: AnimationLocomotionSystem) -> boolean,
	setPoseOverride: (
		self: AnimationLocomotionSystem,
		id: string,
		opts: AnimationPlayerSystem.PlayOpts?
	) -> (boolean, string?),
	clearPoseOverride: (self: AnimationLocomotionSystem) -> (),
	destroy: (self: AnimationLocomotionSystem) -> (),
}

local DEFAULTS = {
	-- Below this move speed the walk pose plays; at or above, run. Default WalkSpeed is 16 and
	-- must read as WALKING (V3 finding — a threshold below it made normal movement play the run
	-- anim). Speed is a STOPGAP signal: the old game decided walk-vs-run by the movement system's
	-- sprint flag, which arrives with the Movement phase; until then, sprint = "faster than
	-- default walk".
	walkRunThreshold = 18,
	-- Divisors: track speed = moveSpeed / scale, so scale = the move speed at which a pose plays
	-- exactly 1x. Default WalkSpeed is 16 and the walk anim is authored to look right there (V5
	-- finding: the old fork DECLARED walk 22 but its AdjustSpeed call was commented out — the old
	-- game actually played everything at 1x, so 22 was dead code, not tuning).
	walkScale = 16,
	runScale = 16,
	climbScale = 5,
	swimScale = 10,
	-- How long after a jump the freefall state keeps showing the jump pose (the stock script's
	-- jumpAnimDuration idea, made explicit).
	jumpDuration = 0.31,
}

-- Standing "still" — the stock script's own threshold.
local IDLE_SPEED = 0.75
-- Swimming slower than this is treading water.
local SWIM_IDLE_SPEED = 1

local DEFAULT_FADE = 0.2
local FADE_BY_POSE: { [string]: number } = {
	-- Snappy transitions where a slow blend reads as lag. `died` fades the STOP on death (there
	-- is no death pose — see handleEvent).
	jump = 0.1,
	died = 0.1,
}

local LocomotionAnimatorModule = {}

--[=[
	@param player PosePlayer -- the character's AnimationPlayerSystem
	@param config Config?
	@return AnimationLocomotionSystem
]=]
function LocomotionAnimatorModule.new(player: PosePlayer, config: Config?): AnimationLocomotionSystem
	local walkRunThreshold = if config ~= nil and config.walkRunThreshold ~= nil
		then config.walkRunThreshold
		else DEFAULTS.walkRunThreshold
	local walkScale = if config ~= nil and config.walkScale ~= nil then config.walkScale else DEFAULTS.walkScale
	local runScale = if config ~= nil and config.runScale ~= nil then config.runScale else DEFAULTS.runScale
	local climbScale = if config ~= nil and config.climbScale ~= nil then config.climbScale else DEFAULTS.climbScale
	local swimScale = if config ~= nil and config.swimScale ~= nil then config.swimScale else DEFAULTS.swimScale
	local jumpDuration = if config ~= nil and config.jumpDuration ~= nil
		then config.jumpDuration
		else DEFAULTS.jumpDuration
	local minRate = if config ~= nil then config.minRate else nil
	local maxRate = if config ~= nil then config.maxRate else nil

	-- A stride's play rate, inside the configured clamp.
	local function strideRate(rate: number): number
		if minRate ~= nil and rate < minRate then
			return minRate
		end
		if maxRate ~= nil and rate > maxRate then
			return maxRate
		end
		return rate
	end

	local enabled = true
	local destroyed = false
	local dead = false
	local overridePose: string? = nil
	local pose: string? = nil
	local handle: AnimationPlayerSystem.PlayHandle? = nil
	local jumpUntil = -math.huge
	-- A freefall reported INSIDE the jump window, applied by `update` once the window ends. The Humanoid
	-- reports Freefall once per fall, usually a few frames after Jumping, so without this memory the fall
	-- pose never plays: the one-shot jump clip ends (~1.2 s) and a longer fall shows no pose at all.
	local pendingFall = false

	-- Switches to `nextPose`, or just retunes speed when the pose is unchanged (replaying a
	-- looped pose would thrash its fade — the failure V3's pose-flap check watches for).
	local function setPose(nextPose: string, trackSpeed: number?)
		if pose == nextPose then
			if trackSpeed ~= nil and handle ~= nil then
				handle:adjustSpeed(trackSpeed)
			end
			return
		end
		local fade = FADE_BY_POSE[nextPose] or DEFAULT_FADE
		if pose ~= nil then
			player:stop(pose, fade)
		end
		local nextHandle = player:play(nextPose, { fadeTime = fade, speed = trackSpeed })
		-- A refused pose (dead id mid-tuning) leaves NO pose rather than a stale one; the next
		-- state event retries. The player already logged the reason.
		pose = if nextHandle ~= nil then nextPose else nil
		handle = nextHandle
	end

	local function stopPose(fadeTime: number?)
		if pose ~= nil then
			player:stop(pose, fadeTime)
			pose = nil
			handle = nil
		end
	end

	local animator: AnimationLocomotionSystem = {
		handleEvent = function(_self: AnimationLocomotionSystem, event: LocomotionEvent, speed: number?, now: number)
			if destroyed or dead then
				return
			end
			if event == "died" then
				-- Death wins over EVERYTHING (PR #13 review finding): an active pose override
				-- (Movement's seam) or a disabled kill switch must not keep a track playing on a
				-- corpse. No death pose (V5 decision — the old game deprecated its death
				-- animation): locomotion stops and latches; the engine's default collapse (and
				-- later the Death/Ragdoll phase) owns what death looks like. Respawn builds a
				-- fresh animator (the shell is a per-character script).
				if overridePose ~= nil then
					player:stop(overridePose, FADE_BY_POSE.died)
					overridePose = nil
					handle = nil
				end
				stopPose(FADE_BY_POSE.died)
				pendingFall = false
				dead = true
				return
			end
			if not enabled or overridePose ~= nil then
				return
			end
			-- Any other state supersedes a remembered fall (a landing, a second jump, a climb).
			if event ~= "freefall" then
				pendingFall = false
			end
			if event == "running" then
				local moveSpeed = speed or 0
				if moveSpeed <= IDLE_SPEED then
					setPose("idle")
				elseif moveSpeed < walkRunThreshold then
					setPose("walk", strideRate(moveSpeed / walkScale))
				else
					setPose("run", strideRate(moveSpeed / runScale))
				end
			elseif event == "jumping" then
				jumpUntil = now + jumpDuration
				setPose("jump")
			elseif event == "freefall" then
				if now >= jumpUntil then
					setPose("fall")
				else
					pendingFall = true
				end
			elseif event == "climbing" then
				setPose("climb", (speed or 0) / climbScale)
			elseif event == "swimming" then
				if (speed or 0) > SWIM_IDLE_SPEED then
					setPose("swim", (speed or 0) / swimScale)
				else
					setPose("swimidle")
				end
			elseif event == "seated" then
				setPose("sit")
			elseif event == "gettingUp" or event == "platformStanding" then
				setPose("idle")
			end
		end,

		--[=[
			Per-frame tick: applies a freefall that arrived inside the jump window once the window has
			ended. Cheap when nothing is pending; the binding calls it every Heartbeat.
		]=]
		update = function(_self: AnimationLocomotionSystem, now: number)
			if not pendingFall or destroyed or dead or not enabled or overridePose ~= nil then
				return
			end
			if now >= jumpUntil then
				pendingFall = false
				setPose("fall")
			end
		end,

		currentPose = function(_self: AnimationLocomotionSystem): string?
			return if overridePose ~= nil then overridePose else pose
		end,

		--[=[
			The kill switch (`LocomotionEnabled` workspace attribute): OFF stops everything and
			ignores events — isolating "is it our animator?" during any investigation — ON resumes
			at idle without a respawn.
		]=]
		setEnabled = function(_self: AnimationLocomotionSystem, nextEnabled: boolean)
			if destroyed or enabled == nextEnabled then
				return
			end
			enabled = nextEnabled
			pendingFall = false
			if not enabled then
				-- Stop the override BEFORE forgetting it (Qodo PR #13): stopPose only knows the
				-- state-driven pose, so clearing overridePose first would orphan its track.
				if overridePose ~= nil then
					player:stop(overridePose, DEFAULT_FADE)
					overridePose = nil
					handle = nil
				end
				stopPose(DEFAULT_FADE)
			elseif not dead then
				setPose("idle")
			end
		end,

		isEnabled = function(_self: AnimationLocomotionSystem): boolean
			return enabled
		end,

		--[=[
			Pins a registry pose over the state-driven ones (the Movement phase's seam: sneak,
			slide, wall-run poses pin here instead of editing this module).
		]=]
		setPoseOverride = function(
			_self: AnimationLocomotionSystem,
			id: string,
			opts: AnimationPlayerSystem.PlayOpts?
		): (boolean, string?)
			if destroyed or not enabled then
				return false, "disabled"
			end
			stopPose(DEFAULT_FADE)
			pendingFall = false
			local overrideHandle, reason = player:play(id, opts)
			if overrideHandle == nil then
				-- Refusal falls back to the state-driven pose so the character is never frozen.
				setPose("idle")
				return false, reason
			end
			overridePose = id
			handle = overrideHandle
			return true, nil
		end,

		clearPoseOverride = function(_self: AnimationLocomotionSystem)
			if overridePose == nil then
				return
			end
			player:stop(overridePose, DEFAULT_FADE)
			overridePose = nil
			handle = nil
			if not destroyed and enabled and not dead then
				setPose("idle")
			end
		end,

		destroy = function(_self: AnimationLocomotionSystem)
			if destroyed then
				return
			end
			if overridePose ~= nil then
				player:stop(overridePose, 0)
				overridePose = nil
			end
			stopPose(0)
			destroyed = true
		end,
	}

	return animator
end

return LocomotionAnimatorModule
