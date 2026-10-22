--!strict
--[=[
	OccupantDoorRules: Mr. Harlow's door beat. Each think he opens every closed door in reach
	(OfficeServiceServer:openDoorsNear); when he opens one he pauses for OccupantConstants.DOOR_BEAT_SECONDS before
	walking on. `hold` turns a walk (`goTo`) into standing still while the beat lasts. Anything else passes through
	unchanged, so a catch (`attack`) is never held. Pure.

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

return OccupantDoorRules
