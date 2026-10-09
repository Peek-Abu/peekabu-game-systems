--!strict
--[=[
	NpcConstants: tag and attribute names, default kind values, and tick / path / corpse tuning.

	@class NpcConstants
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)

-- Everything an NpcDefInput may leave out.
local DEFAULTS: NpcTypes.NpcDef = {
	attitude = "passive",
	walkSpeed = 8,
	runSpeed = 16,
	sightRange = 60,
	sightAngle = 140,
	loseSightTime = 4,
	wanderRadius = 20,
	fleeRange = 20,
	attackRange = 5,
	attackDamage = 20,
	attackCooldown = 1.5,
	corpseTime = 10,
}

local NpcConstants = {
	DEFAULTS = DEFAULTS,
	-- A model with this tag and a registered NpcKind attribute is an NPC.
	TAG = "Npc",
	KIND_ATTRIBUTE = "NpcKind",
	-- Names a Folder of BaseParts (anywhere in Workspace) visited in name order.
	PATROL_ATTRIBUTE = "NpcPatrol",
	-- Templates: ServerStorage.<TEMPLATE_ROOT>.<TEMPLATE_FOLDER>.<def.template> (artist-owned).
	TEMPLATE_ROOT = "Assets",
	TEMPLATE_FOLDER = "Npcs",
	-- Where spawned NPCs are parented in Workspace (created at runtime).
	WORKSPACE_FOLDER = "Npcs",
	-- Seconds between one NPC's thinks.
	THINK_INTERVAL = 0.25,
	-- Re-path when the goal moved this far, or the path is this old (seconds).
	REPATH_DISTANCE = 4,
	REPATH_MAX_AGE = 2,
	-- Close enough to a waypoint or goal to count as reached.
	REACHED_DISTANCE = 3,
	-- Pause between wander legs (seconds, min and max).
	WANDER_PAUSE = { 2, 5 },
	-- Below this horizontal speed the NPC counts as standing.
	IDLE_SPEED = 0.5,
}

return NpcConstants
