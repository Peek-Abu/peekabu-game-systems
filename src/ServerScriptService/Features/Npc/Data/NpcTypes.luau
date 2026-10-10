--!strict
--[=[
	NpcTypes: NPC kinds, intents and the brain's context (design:
	docs/superpowers/specs/2026-10-09-npc-design.md).

	@class NpcTypes
]=]

-- passive ignores players; hostile chases and attacks what it sees; timid flees from players in range.
export type Attitude = "passive" | "hostile" | "timid"

-- Animation registry ids per pose (AnimationServiceServer:playOnRig). All optional.
export type NpcAnimations = {
	idle: string?,
	walk: string?,
	run: string?,
	attack: string?,
}

export type NpcDef = {
	template: string?,
	attitude: Attitude,
	walkSpeed: number,
	runSpeed: number,
	sightRange: number,
	sightAngle: number,
	loseSightTime: number,
	wanderRadius: number,
	fleeRange: number,
	attackRange: number,
	attackDamage: number,
	attackCooldown: number,
	corpseTime: number,
	animations: NpcAnimations?,
	-- PathfindingService costs by material/label name (math.huge = never enter). Absent = defaults.
	pathCosts: { [string]: number }?,
}

-- What a game passes to NpcRegistry.register: everything but the attitude has a default.
export type NpcDefInput = {
	template: string?,
	attitude: Attitude,
	walkSpeed: number?,
	runSpeed: number?,
	sightRange: number?,
	sightAngle: number?,
	loseSightTime: number?,
	wanderRadius: number?,
	fleeRange: number?,
	attackRange: number?,
	attackDamage: number?,
	attackCooldown: number?,
	corpseTime: number?,
	animations: NpcAnimations?,
	-- PathfindingService costs by material/label name (math.huge = never enter). Absent = defaults.
	pathCosts: { [string]: number }?,
}

-- What the brain sees this tick. `target` is a player the NPC sees or remembers; `threat` the nearest
-- player at all (for fleeing); `position` is the NPC's own; `now` is os.clock().
export type BrainContext = {
	target: { userId: number, distance: number, position: Vector3 }?,
	threat: { position: Vector3, distance: number }?,
	hasPatrol: boolean,
	position: Vector3,
	now: number,
}

export type Intent =
	{ kind: "idle" }
	| { kind: "wander" }
	| { kind: "patrol" }
	| { kind: "chase", target: number }
	| { kind: "attack", target: number }
	| { kind: "flee", from: Vector3 }
	| { kind: "goTo", position: Vector3, run: boolean }

-- Runtime overrides for one live NPC (a game's pressure tiers). Nil fields keep the kind's value.
export type NpcTuning = {
	walkSpeed: number?,
	runSpeed: number?,
	sightRange: number?,
	sightAngle: number?,
}

-- A game's brain for one kind. Returning nil uses the default brain (NpcBrainRules.decide) this tick.
export type Brain = (def: NpcDef, context: BrainContext, npc: Model) -> Intent?

export type Pose = "idle" | "walk" | "run"

return {}
