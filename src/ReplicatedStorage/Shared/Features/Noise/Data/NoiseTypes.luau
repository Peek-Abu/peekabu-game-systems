--!strict
--[=[
	NoiseTypes: the Noise feature's shapes (Cleanup Crew spec §6.2 "Noise"). Types only (spec-exempt).

	@class NoiseTypes
]=]

-- One noise: where, how far it carries before any hearing scale (studs), and what made it ("vacuum",
-- "drop", "search", "rattle", ...).
export type NoiseEvent = {
	position: Vector3,
	radius: number,
	source: string,
}

return {}
