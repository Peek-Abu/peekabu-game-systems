--!strict
--[=[
	OccupantCatchRules: whether Harlow may catch a player right now (Cleanup Crew spec §4 "Catch", "Grace",
	§6.4 "Catches are decided on the server tick"): alive, not already being caught, not on his break, not in
	their grace, outside the truck's box, not hidden where he did not see them go in, and within reach (`reach`:
	CATCH_RANGE plus CATCH_SLACK, since the base checks the range a moment earlier; FOUND_REACH more for a found hider). `launch` is the throw: away from him, flat, plus an upward kick. Pure.

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
	if input.hidden == true then
		return false, "hidden"
	end
	if input.reachable == false then
		return false, "outside grab volume"
	end
	if input.clear == false then
		return false, "blocked"
	end
	if not (input.distance <= OccupantCatchRules.reach(input.found == true)) then
		return false, "too far"
	end
	return true, nil
end

--[=[
	The flat studs a catch may reach: CATCH_RANGE plus CATCH_SLACK, and FOUND_REACH more for a hider he found at their
	spot (`found`: the check, the cabinet he opened, the sit-in), whose stand point can sit a little further off than a
	chase's grab (the straight-out stand point beside a cabinet or a table).
]=]
function OccupantCatchRules.reach(found: boolean): number
	local range = OccupantConstants.CATCH_RANGE + OccupantConstants.CATCH_SLACK
	return if found then range + OccupantConstants.FOUND_REACH else range
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
