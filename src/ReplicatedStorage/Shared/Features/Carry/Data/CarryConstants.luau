--!strict
--[=[
	CarryConstants: carry tuning and names. Static data (spec-exempt).

	@class CarryConstants
]=]

return table.freeze({
	-- CollectionService tag a builder puts on a carryable object.
	TAG = "Carryable",
	-- String attribute naming the object's CarryRegistry kind.
	KIND_ATTRIBUTE = "CarryKind",
	-- Number attribute set on a held object: the carrier's UserId (absent when not held).
	CARRIED_BY_ATTRIBUTE = "CarriedBy",
	-- The public-player field naming what a player carries.
	PUBLIC_FIELD = "carrying",
	-- The interaction kind the Carry server registers for pick-up.
	INTERACTION_KIND = "carry",
	-- Walk speed lost per unit of weight (a fraction of base speed), and the floor it never goes below.
	SLOW_PER_WEIGHT = 0.05,
	MIN_SPEED_MULTIPLIER = 0.4,
	DEFAULT_HOLD_OFFSET = CFrame.new(0, 0.5, -2.5),
	-- Where a dropped object is placed, relative to the HumanoidRootPart.
	DROP_OFFSET = CFrame.new(0, 0, -3),
	-- Keeping placements inside (CarryPlacementSystem): studs kept between a placed object and a wall, beyond
	-- its own half-width; how far above a point the floor probe starts and how far down it reaches; how far a
	-- placement's floor may sit above or below the floor under the safe origin; how long a throw is watched.
	WALL_MARGIN = 0.15,
	FLOOR_PROBE_LIFT = 0.5,
	FLOOR_PROBE = 20,
	FLOOR_STEP = 1.5,
	THROW_GUARD_SECONDS = 4,
	DEFAULT_THROW_SPEED = 45,
	-- Upward speed added to a throw so it arcs.
	THROW_LIFT = 12,
	-- The tag on the joint a hanging bag swings from (a Motor6D at its handle; CarrySwaySystem drives it on clients),
	-- the swing's tuning (CarryFormulas.swayStep) and the largest hand acceleration it reacts to (studs/s²).
	HANG_TAG = "CarryHang",
	-- The tag on the joint a pushed item rides the root by (a Motor6D; CarryPushSystem slides it on clients to keep its
	-- place in front of the carrier's chest as the walk moves the torso), and the joint's attribute holding where the
	-- carrier's UpperTorso is at rest (a Vector3 in root space) that the slide is measured from.
	PUSH_TAG = "CarryPush",
	TORSO_REST_ATTRIBUTE = "CarryTorsoRest",
	SWAY = table.freeze({ omega = 7, damping = 0.35, maxTilt = math.rad(25) }),
	SWAY_ACCEL_MAX = 120,
})
