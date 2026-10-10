--!strict
--[=[
	NoiseConstants: the ripple ring's look (Cleanup Crew spec §7: "any noise: faint ripple ring on the floor at
	the radius Harlow hears it"). Placeholder graybox look; M3 restyles it. The radii themselves live with
	their sources (VacuumConstants, CargoConstants). Static data (spec-exempt).

	@class NoiseConstants
]=]

return table.freeze({
	RIPPLE_NAME = "NoiseRipple",
	-- Seconds the ring takes to spread to its radius and fade out.
	RIPPLE_SECONDS = 0.8,
	RIPPLE_COLOR = Color3.fromRGB(180, 210, 255),
	RIPPLE_TRANSPARENCY = 0.8,
	RIPPLE_THICKNESS = 0.1,
	-- How far down the floor is looked for under a noise.
	FLOOR_PROBE = 12,
})
