--!strict
--[=[
	TrainingCoachRules: what keeps the hub's Training coach alive (owner 11-11: "feels like a statue";
	TrainingConstants.HUB_COACH): where her head turns to follow the player, how it eases there, and when she waves.

	@class TrainingCoachRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

local LOOK = TrainingConstants.HUB_COACH.LOOK
local WAVE = TrainingConstants.HUB_COACH.WAVE

local TrainingCoachRules = {}

--[=[
	The head's turn toward the player at `offset` (studs, in her body's space: forward is -Z): yaw (radians, + turns
	toward -X) and pitch (+ looks up), each within what a neck can do. Ahead (0, 0) when the player is behind her,
	out of range, or right on her.
]=]
function TrainingCoachRules.headTurn(offset: Vector3): (number, number)
	local flat = Vector2.new(offset.X, offset.Z).Magnitude
	if flat < 1e-3 or flat > LOOK.RANGE then
		return 0, 0
	end
	local yaw = math.atan2(-offset.X, -offset.Z)
	if math.abs(yaw) > math.rad(LOOK.BEHIND) then
		return 0, 0
	end
	local pitch = math.atan2(offset.Y, flat)
	local maxYaw, maxPitch = math.rad(LOOK.MAX_YAW), math.rad(LOOK.MAX_PITCH)
	return math.clamp(yaw, -maxYaw, maxYaw), math.clamp(pitch, -maxPitch, maxPitch)
end

--[=[
	`current` moved toward `target` over `dt` seconds (a smooth catch-up that never overshoots).
]=]
function TrainingCoachRules.ease(current: number, target: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-LOOK.RATE * dt))
end

--[=[
	When she next waves on her own after `now`, `roll` (0..1) of the way between WAVE.MIN and WAVE.MAX seconds.
]=]
function TrainingCoachRules.nextWave(now: number, roll: number): number
	return now + WAVE.MIN + (WAVE.MAX - WAVE.MIN) * math.clamp(roll, 0, 1)
end

--[=[
	Whether she waves now: the player (`distance` studs away, nil without a character) just walked up (`wasNear`:
	they were already near last frame), or it is time for her own wave (`now` has reached `due`).
]=]
function TrainingCoachRules.wavesNow(distance: number?, wasNear: boolean, now: number, due: number): boolean
	if distance ~= nil and distance <= WAVE.RADIUS and not wasNear then
		return true
	end
	return now >= due
end

return TrainingCoachRules
