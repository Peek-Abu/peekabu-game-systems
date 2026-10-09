--!strict
--[=[
	NpcRegistry: the NPC kinds (the ItemRegistry contract: validated, loud at boot, no re-registration).
	Unset fields take NpcConstants.DEFAULTS.

	@class NpcRegistry
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local NpcConstants = require(ServerScriptService.Features.Npc.Data.NpcConstants)
local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)

type NpcDef = NpcTypes.NpcDef

local defs: { [string]: NpcDef } = {}

local NpcRegistry = {}

--[=[
	Registers a kind. Asserts: new kind; a known attitude; non-negative numbers; runSpeed ≥ walkSpeed;
	sightAngle within 0-360.
]=]
function NpcRegistry.register(kind: string, input: NpcTypes.NpcDefInput)
	assert(kind ~= "", "npc kind must not be empty")
	assert(defs[kind] == nil, `npc kind "{kind}" is already registered`)
	local attitude = input.attitude
	assert(
		attitude == "passive" or attitude == "hostile" or attitude == "timid",
		`npc kind "{kind}": unknown attitude "{tostring(attitude)}"`
	)
	local base = NpcConstants.DEFAULTS
	local def: NpcDef = {
		template = input.template,
		attitude = attitude,
		walkSpeed = input.walkSpeed or base.walkSpeed,
		runSpeed = input.runSpeed or base.runSpeed,
		sightRange = input.sightRange or base.sightRange,
		sightAngle = input.sightAngle or base.sightAngle,
		loseSightTime = input.loseSightTime or base.loseSightTime,
		wanderRadius = input.wanderRadius or base.wanderRadius,
		fleeRange = input.fleeRange or base.fleeRange,
		attackRange = input.attackRange or base.attackRange,
		attackDamage = input.attackDamage or base.attackDamage,
		attackCooldown = input.attackCooldown or base.attackCooldown,
		corpseTime = input.corpseTime or base.corpseTime,
		animations = input.animations,
	}
	for _, value in
		{
			def.walkSpeed,
			def.runSpeed,
			def.sightRange,
			def.loseSightTime,
			def.wanderRadius,
			def.fleeRange,
			def.attackRange,
			def.attackDamage,
			def.attackCooldown,
			def.corpseTime,
		}
	do
		assert(value >= 0, `npc kind "{kind}": numbers must not be negative`)
	end
	assert(def.runSpeed >= def.walkSpeed, `npc kind "{kind}": runSpeed must be at least walkSpeed`)
	assert(def.sightAngle >= 0 and def.sightAngle <= 360, `npc kind "{kind}": sightAngle must be 0-360`)
	defs[kind] = table.freeze(def)
end

function NpcRegistry.get(kind: string): NpcDef?
	return defs[kind]
end

function NpcRegistry.has(kind: string): boolean
	return defs[kind] ~= nil
end

function NpcRegistry.kinds(): { string }
	local list: { string } = {}
	for kind in defs do
		table.insert(list, kind)
	end
	table.sort(list)
	return list
end

return NpcRegistry
