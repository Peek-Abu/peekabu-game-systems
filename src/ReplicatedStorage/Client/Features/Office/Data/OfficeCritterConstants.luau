--!strict
--[=[
	OfficeCritterConstants: the yard's critters (yard design doc §4: harmless dressing, the outside stays a safe zone).
	A critter is a Model the builder places in Workspace.YardDressing, tagged TAG, with its kind in KIND_ATTRIBUTE, the
	horizontal way it runs off in DIRECTION_ATTRIBUTE (away from the walk), and for the cat how far below its perch the
	ground is in DROP_ATTRIBUTE. Per kind: how near a player comes before it flees, how long the flee lasts, and how
	long it stays gone. Every number is a tuning hypothesis. Static data (spec-exempt).

	@class OfficeCritterConstants
]=]

export type CritterKind = "cat" | "crow" | "raccoon"

export type KindTuning = {
	-- A player within this (studs) sets it off.
	near: number,
	-- The flee lasts this long (s); then the critter is hidden.
	fleeTime: number,
	-- It stays gone at least this long (s) before it comes back.
	returnAfter: number,
	-- cat: the hop off its perch lasts this long (s), rising hopHeight before it lands drop lower.
	hopTime: number,
	hopHeight: number,
	-- Ground speed (cat) or flight speed along the flee direction (crow), studs/s.
	speed: number,
	-- crow: climb rate, studs/s.
	climb: number,
	-- raccoon: how far it ducks into the dumpster (all of it below the rim).
	duck: number,
	-- Idle: a small turn of up to idleTurnDegrees every idleTurnEvery s (0: still).
	idleTurnDegrees: number,
	idleTurnEvery: number,
}

local KINDS: { [CritterKind]: KindTuning } = {
	cat = {
		near = 14,
		fleeTime = 1.6,
		returnAfter = 30,
		hopTime = 0.45,
		hopHeight = 1.4,
		speed = 18,
		climb = 0,
		duck = 0,
		idleTurnDegrees = 20,
		idleTurnEvery = 5,
	},
	crow = {
		near = 18,
		fleeTime = 2.2,
		returnAfter = 35,
		hopTime = 0,
		hopHeight = 0,
		speed = 14,
		climb = 9,
		duck = 0,
		idleTurnDegrees = 35,
		idleTurnEvery = 3,
	},
	raccoon = {
		near = 10,
		fleeTime = 0.35,
		returnAfter = 12,
		hopTime = 0,
		hopHeight = 0,
		speed = 0,
		climb = 0,
		duck = 2.2,
		idleTurnDegrees = 15,
		idleTurnEvery = 4,
	},
}

return {
	TAG = "OfficeCritter",
	KIND_ATTRIBUTE = "CritterKind",
	DIRECTION_ATTRIBUTE = "FleeDirection",
	DROP_ATTRIBUTE = "FleeDrop",
	-- A gone critter comes back only when no player is within this (studs), so nobody sees it pop in.
	RETURN_CLEAR = 30,
	-- Players are measured this often (s); the pose is written every frame.
	SENSE_EVERY = 0.15,
	KINDS = KINDS,
}
