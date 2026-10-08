--!strict
--[=[
	ReplicationPuppetLocomotionSystem: turns a puppet's interpolated movement into AnimationLocomotionSystem events (character
	replication R3 spec, "Viewer and owner client"; parent spec §6.8). Puppets reuse the owner's animation
	code path (an AnimationPlayerSystem and an AnimationLocomotionSystem each); this replaces the Humanoid signals the
	owner's binding forwards, with no new network traffic: the movement record already carries the state.

	- The record's state (`HumanoidStateType % 32`, the nearest sample at render time) picks the event the
	  owner's Humanoid would have fired: running (Running, RunningNoPhysics, Landed), jumping, freefall,
	  climbing, swimming, seated, gettingUp, platformStanding, died. Any other state (ragdoll, physics,
	  falling down) sends nothing, so the current pose holds.
	- Speed is what the owner's signal carries: horizontal speed for running, vertical for climbing, full
	  speed for swimming.
	- An event goes out only on change: another event, or for a speed-carrying one a speed change of at
	  least `MIN_SPEED_STEP` studs/s or `RATE_STEP` of the last sent speed (no per-frame retuning).
	- The grounded flag is deliberately not used: the owner's animator decides by state alone, and the
	  puppet must play exactly what the owner plays.

	Pure.

	@class ReplicationPuppetLocomotionSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationLocomotionSystem = require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionSystem)

type LocomotionEvent = AnimationLocomotionSystem.LocomotionEvent

local ReplicationPuppetLocomotionSystem = {}

ReplicationPuppetLocomotionSystem.MIN_SPEED_STEP = 0.25
ReplicationPuppetLocomotionSystem.RATE_STEP = 0.05
-- The stride play-rate clamp puppets give their AnimationLocomotionSystem (§6.8).
ReplicationPuppetLocomotionSystem.MIN_RATE = 0.7
ReplicationPuppetLocomotionSystem.MAX_RATE = 1.4

local STATE = Enum.HumanoidStateType
local EVENT_BY_STATE: { [number]: LocomotionEvent } = {
	[STATE.Running.Value] = "running",
	[STATE.RunningNoPhysics.Value] = "running",
	[STATE.Landed.Value] = "running",
	[STATE.Jumping.Value] = "jumping",
	[STATE.Freefall.Value] = "freefall",
	[STATE.Climbing.Value] = "climbing",
	[STATE.Swimming.Value] = "swimming",
	[STATE.Seated.Value] = "seated",
	[STATE.GettingUp.Value] = "gettingUp",
	[STATE.PlatformStanding.Value] = "platformStanding",
	[STATE.Dead.Value] = "died",
}

export type Tracker = {
	lastEvent: LocomotionEvent?,
	lastSpeed: number,
}

function ReplicationPuppetLocomotionSystem.new(): Tracker
	return { lastEvent = nil, lastSpeed = 0 }
end

--[=[
	Forget what was sent, so the next step re-sends the current event (a fresh AnimationLocomotionSystem, an
	unfrozen puppet).
]=]
function ReplicationPuppetLocomotionSystem.reset(tracker: Tracker)
	tracker.lastEvent = nil
	tracker.lastSpeed = 0
end

local function speedFor(event: LocomotionEvent, velocity: Vector3): number?
	if event == "running" then
		return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	elseif event == "climbing" then
		return math.abs(velocity.Y)
	elseif event == "swimming" then
		return velocity.Magnitude
	end
	return nil
end

--[=[
	This frame's event for the puppet, or nil when nothing changed enough. `state` is the record's state
	value, `velocity` the sample's sent velocity.
]=]
function ReplicationPuppetLocomotionSystem.step(
	tracker: Tracker,
	state: number,
	velocity: Vector3
): (LocomotionEvent?, number?)
	local event: LocomotionEvent? = EVENT_BY_STATE[state]
	if event == nil then
		return nil, nil
	end
	local speed = speedFor(event, velocity)
	if event == tracker.lastEvent then
		if speed == nil then
			return nil, nil
		end
		local last = tracker.lastSpeed
		if
			math.abs(speed - last)
			< math.max(
				ReplicationPuppetLocomotionSystem.MIN_SPEED_STEP,
				last * ReplicationPuppetLocomotionSystem.RATE_STEP
			)
		then
			return nil, nil
		end
	end
	tracker.lastEvent = event
	tracker.lastSpeed = speed or 0
	return event, speed
end

return ReplicationPuppetLocomotionSystem
