--!strict
--[=[
	DeathTypes: the death flow's shapes (design: docs/superpowers/specs/2026-10-09-death-design.md).

	@class DeathTypes
]=]

export type RespawnPolicy = "auto" | "manual"

--[=[
	- respawn: `auto` = the engine respawns after `respawnDelay`; `manual` = only `respawn(player)` does.
	- ragdoll: replace the engine's joint break with a ragdoll.
	- creditWindow: how long (seconds) a damage source stays credited for a kill.
]=]
export type DeathConfig = {
	respawn: RespawnPolicy,
	respawnDelay: number,
	ragdoll: boolean,
	creditWindow: number,
}

export type DeathConfigUpdate = {
	respawn: RespawnPolicy?,
	respawnDelay: number?,
	ragdoll: boolean?,
	creditWindow: number?,
}

-- Who dealt damage: a player (userId) or anything else by name (an NPC kind, "fall", "trap").
export type DamageSource = {
	userId: number?,
	name: string,
}

export type DeathInfo = {
	killerUserId: number?,
	killerName: string?,
	cause: string?,
}

-- A ragdoll joint's limits, in degrees: the cone half-angle and the twist range.
export type JointLimits = {
	upperAngle: number,
	twistLower: number,
	twistUpper: number,
}

-- Where a player's next character appears; nil = where the engine put it (a SpawnLocation).
-- Must not yield.
export type SpawnResolver = (player: Player) -> CFrame?

export type KillOptions = {
	-- Velocity (studs/s) every body part gets at the moment of death: a throw, a blast.
	launch: Vector3?,
}

return {}
