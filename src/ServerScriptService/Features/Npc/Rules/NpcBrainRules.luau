--!strict
--[=[
	NpcBrainRules: the NPC's decision for this tick, and its locomotion pose. Pure.

	Priority, by attitude: a hostile NPC attacks a target in range, else chases it; a timid NPC flees a
	threat inside fleeRange; then any NPC patrols its route, wanders, or idles.

	@class NpcBrainRules
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local NpcConstants = require(ServerScriptService.Features.Npc.Data.NpcConstants)
local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)

type Intent = NpcTypes.Intent

-- Speed above walkSpeed that still counts as walking (the humanoid overshoots a little).
local WALK_TOLERANCE = 0.5

local NpcBrainRules = {}

function NpcBrainRules.decide(def: NpcTypes.NpcDef, context: NpcTypes.BrainContext): Intent
	local target = context.target
	if def.attitude == "hostile" and target ~= nil then
		if target.distance <= def.attackRange then
			return { kind = "attack", target = target.userId }
		end
		return { kind = "chase", target = target.userId }
	end
	local threat = context.threat
	if def.attitude == "timid" and threat ~= nil and threat.distance <= def.fleeRange then
		return { kind = "flee", from = threat.position }
	end
	if context.hasPatrol then
		return { kind = "patrol" }
	end
	if def.wanderRadius > 0 then
		return { kind = "wander" }
	end
	return { kind = "idle" }
end

function NpcBrainRules.poseFor(speed: number, walkSpeed: number): NpcTypes.Pose
	if speed < NpcConstants.IDLE_SPEED then
		return "idle"
	end
	if speed <= walkSpeed + WALK_TOLERANCE then
		return "walk"
	end
	return "run"
end

return NpcBrainRules
