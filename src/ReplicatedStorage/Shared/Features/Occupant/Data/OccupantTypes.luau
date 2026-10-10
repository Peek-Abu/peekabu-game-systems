--!strict
--[=[
	OccupantTypes: Mr. Harlow's shapes (Cleanup Crew spec §4 "Mr. Harlow"). Shared: the client reads his mode
	from an attribute. Types only (spec-exempt).

	@class OccupantTypes
]=]

-- What he is doing: walking his route, checking a noise, chasing someone he sees, searching where he lost
-- them, on the shift's break, or standing over a catch.
export type Mode = "patrol" | "investigate" | "chase" | "search" | "rest" | "catch"

-- A moment worth a speech bubble (OccupantConstants.LINES).
export type Cue = "spotted" | "curious" | "giveUp" | "resting" | "caught"

-- An axis-aligned box in the world (the loading bay).
export type Zone = {
	min: Vector3,
	max: Vector3,
}

-- His memory between thinks. Times are os.clock() seconds.
export type Mind = {
	mode: Mode,
	-- When the current mode began.
	since: number,
	-- The route point he is walking to, and which way round he walks (1 or -1).
	routeIndex: number,
	routeStep: number,
	-- The UserId he is chasing.
	target: number?,
	-- Where he last saw his target (always outside the loading bay).
	lastSeen: Vector3?,
	-- The noise he is investigating.
	noise: Vector3?,
	-- When he reached the investigate / search point (looking around since).
	arrivedAt: number?,
	-- UserId → the os.clock() until which he ignores them (after a catch).
	grace: { [number]: number },
}

-- One crew member as the service saw them this think; `clear` is the line-of-sight ray's verdict.
export type Glimpse = {
	userId: number,
	position: Vector3,
	clear: boolean,
}

-- Everything the brain decides from, gathered by OccupantServiceServer each think.
export type Senses = {
	position: Vector3,
	look: Vector3,
	now: number,
	sightRange: number,
	sightAngle: number,
	players: { Glimpse },
	-- The last noise he heard since the previous think (already through NoiseRules).
	heard: Vector3?,
	-- The shift's break: he walks to `restPoint` and ignores everyone.
	resting: boolean,
	route: { Vector3 },
	restPoint: Vector3,
	zone: Zone,
}

-- What the catch rule needs about a would-be catch.
export type CatchInput = {
	distance: number,
	position: Vector3,
	alive: boolean,
	-- Their catch sequence is already running.
	catching: boolean,
	inGrace: boolean,
	resting: boolean,
	zone: Zone,
}

return {}
