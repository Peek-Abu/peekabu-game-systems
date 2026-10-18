--!strict
--[=[
	NoiseConstants: the ripple ring's look (Cleanup Crew spec §7: "any noise: faint ripple ring on the floor at the
	radius Harlow hears it"). A thin pale ring that spreads from a quarter of the heard radius out to all of it,
	thinning and fading (NoiseRippleFormulas). The radii themselves live with their sources (VacuumConstants,
	CargoConstants). Static data (spec-exempt).

	@class NoiseConstants
]=]

return table.freeze({
	RIPPLE_NAME = "NoiseRipple",
	-- Seconds from the noise to the ring vanishing at the heard radius.
	RIPPLE_SECONDS = 1.1,
	RIPPLE_COLOR = Color3.fromRGB(205, 225, 255),
	-- The ring starts at this fraction of the heard radius and eases out to all of it.
	RIPPLE_START_FRACTION = 0.25,
	-- Its band starts this fraction of the radius wide and thins to RIPPLE_MIN_WIDTH studs.
	RIPPLE_WIDTH_FRACTION = 0.12,
	RIPPLE_MIN_WIDTH = 0.5,
	-- Faint: it starts this transparent and fades to nothing.
	RIPPLE_START_TRANSPARENCY = 0.55,
	-- The ring's thickness, and how far above the floor it floats (no z-fighting).
	RIPPLE_HEIGHT = 0.05,
	RIPPLE_LIFT = 0.06,
	-- A ripple whose ring never comes within this many studs of the camera is not drawn.
	RIPPLE_MAX_DISTANCE = 200,
	-- How far down the floor is looked for under a noise.
	FLOOR_PROBE = 12,
})
