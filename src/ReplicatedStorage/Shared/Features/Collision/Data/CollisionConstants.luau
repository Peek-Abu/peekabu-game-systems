--!strict
--[=[
	CollisionConstants (R6 spec 2026-10-08 §3): the player-collision size table and tuning.

	Offsets are relative to the HumanoidRootPart, in studs, measured on the Venture rig (2026-09-24). The
	values are the CP7 spike's, unchanged; the 20/22 buffer and the 10 Hz range check are R6's. This table
	is also the contract a later anti-cheat phase reads for "players are ground and walls" (spec decision 3).

	@class CollisionConstants
]=]

local CollisionConstants = {
	-- The capsule: radius, bottom of the feet, top of the head.
	RADIUS = 1.1,
	BOTTOM = -4.05,
	TOP = 1.53,
	-- A blocker turns solid at SOLID_RANGE or closer and off beyond RELEASE_RANGE (a buffer, so a player
	-- pacing the edge doesn't flip it), checked RANGE_CHECK_HZ times a second.
	SOLID_RANGE = 20,
	RELEASE_RANGE = 22,
	RANGE_CHECK_HZ = 10,
	-- Slide-off: while my feet rest on a head (within ±REST_GAP of its top, not rising faster than
	-- REST_MAX_RISE), my outward speed is raised to SLIDE_OFF_SPEED. Within CENTRE_EPSILON of their centre
	-- the push follows my facing.
	SLIDE_OFF_SPEED = 12,
	REST_GAP = 0.6,
	REST_MAX_RISE = 1,
	CENTRE_EPSILON = 0.2,
	PUPPET_GROUP = "CollisionPuppetBlocker",
	SELF_GROUP = "CollisionSelfCollider",
	-- density 0.7, friction 0, elasticity 0, FrictionWeight 100 (it wins the contact), ElasticityWeight 1.
	FRICTIONLESS = PhysicalProperties.new(0.7, 0, 0, 100, 1),
	-- Workspace attribute; true draws the capsules.
	DEBUG_ATTRIBUTE = "CollisionDebug",
	DEBUG_TRANSPARENCY = 0.6,
	PUPPET_COLOR = Color3.fromRGB(235, 70, 70),
	SELF_COLOR = Color3.fromRGB(70, 140, 235),
}

return CollisionConstants
