--!strict
--[=[
	OccupantCatchRules: whether Harlow may catch a player right now (Cleanup Crew spec §4 "Catch", "Grace",
	§6.4 "Catches are decided on the server tick"): alive, not already being caught, not on his break, not in
	their grace, outside the loading bay, and within reach (CATCH_RANGE plus CATCH_SLACK, since the base checks
	the range a moment earlier). `launch` is the throw: away from him, flat, plus an upward kick. Pure.

	@class OccupantCatchRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantBrainRules = require(ServerScriptService.Features.Occupant.Rules.OccupantBrainRules)

local OccupantCatchRules = {}

function OccupantCatchRules.canCatch(input: OccupantTypes.CatchInput): (boolean, string?)
	if not input.alive then
		return false, "not alive"
	end
	if input.catching then
		return false, "already caught"
	end
	if input.resting then
		return false, "on break"
	end
	if input.inGrace then
		return false, "grace"
	end
	if OccupantBrainRules.inZone(input.position, input.zone) then
		return false, "safe zone"
	end
	if input.distance > OccupantConstants.CATCH_RANGE + OccupantConstants.CATCH_SLACK then
		return false, "too far"
	end
	return true, nil
end

--[=[
	The ragdoll launch velocity: `speed` along the flat direction from `from` (Harlow) to `to` (the player),
	plus `up`. Straight along +X when they share a spot.
]=]
function OccupantCatchRules.launch(from: Vector3, to: Vector3, speed: number, up: number): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
	return direction * speed + Vector3.new(0, up, 0)
end

return OccupantCatchRules
