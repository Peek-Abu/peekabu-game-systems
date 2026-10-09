--!strict
--[=[
	CarryTypes: the types the Carry feature shares. Types only (spec-exempt).
	Design: docs/superpowers/specs/2026-10-09-carry-design.md.

	@class CarryTypes
]=]

export type CarryDef = {
	-- Slows the carrier (see CarryFormulas.walkSpeedFor). 0 = no slowdown.
	weight: number,
	throwable: boolean?,
	-- Studs per second along the aim; absent = CarryConstants.DEFAULT_THROW_SPEED.
	throwSpeed: number?,
	-- Where the object sits relative to the HumanoidRootPart; absent = CarryConstants.DEFAULT_HOLD_OFFSET.
	holdOffset: CFrame?,
}

return {}
