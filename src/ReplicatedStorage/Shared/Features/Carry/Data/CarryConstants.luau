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
	DEFAULT_THROW_SPEED = 45,
	-- Upward speed added to a throw so it arcs.
	THROW_LIFT = 12,
})
