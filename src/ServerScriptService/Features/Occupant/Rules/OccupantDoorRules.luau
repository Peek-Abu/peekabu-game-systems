--!strict
--[=[
	OccupantDoorRules: Mr. Harlow's door beat. Each think he opens every closed door in reach
	(OfficeServiceServer:openDoorsNear); when he opens one he pauses for OccupantConstants.DOOR_BEAT_SECONDS before
	walking on. `hold` turns a walk (`goTo`) into standing still while the beat lasts. Anything else passes through
	unchanged, so a catch (`attack`) is never held. He only takes the beat for a door he opens AHEAD of him
	(OfficeDoorUtils.ahead): `heading` is the direction he is going, which the think hands openDoorsNear. Pure.

	His NPC intents have no "stand" kind: `idle` is the one that halts him in place.

	@class OccupantDoorRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)

local OccupantDoorRules = {}

-- `intent`, or standing still (`idle`) when it is a walk and `now` is before `holdUntil`.
function OccupantDoorRules.hold(intent: NpcTypes.Intent, now: number, holdUntil: number): NpcTypes.Intent
	if intent.kind == "goTo" and now < holdUntil then
		return { kind = "idle" }
	end
	return intent
end

-- Below this ground-plane speed (studs/s) he counts as standing still.
local MOVING_SPEED = 0.5

--[=[
	The direction he is going, flat (Y = 0) and unit: his ground-plane `velocity` while he moves, else the direction
	from `position` to `goal` (his current walk target, if any), else nil (no heading: every door counts as ahead).
]=]
function OccupantDoorRules.heading(velocity: Vector3, position: Vector3, goal: Vector3?): Vector3?
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	if flat.Magnitude >= MOVING_SPEED then
		return flat.Unit
	end
	if goal ~= nil then
		local toward = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
		if toward.Magnitude > 1e-3 then
			return toward.Unit
		end
	end
	return nil
end

return OccupantDoorRules
