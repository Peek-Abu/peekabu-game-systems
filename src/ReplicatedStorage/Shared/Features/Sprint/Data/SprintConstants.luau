--!strict
--[=[
	SprintConstants: sprinting with stamina (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §3).
	Every number is a tuning hypothesis. Static data (spec-exempt).

	The race: walking (16) loses to the Manager's chase (20, 21 at the top tier); a sprint (23) beats it by 2-3 studs a
	second for STAMINA_SECONDS, about 12-18 studs of lead (2026-10-16: 4.5 s was too little to really get away), enough
	to break his line of sight round a corner or reach a hiding spot, not to run forever.

	@class SprintConstants
]=]

return table.freeze({
	-- The base Input action (Shift / L3) the client holds.
	ACTION = "sprint",
	SPRINT_SPEED = 23,
	-- A full bar lasts STAMINA_SECONDS of moving sprint; it starts refilling REGEN_DELAY seconds after the last drain and
	-- refills from empty in REGEN_SECONDS. Run dry, a sprint cannot start again until the bar is back to
	-- RESTART_FRACTION.
	STAMINA_SECONDS = 6,
	REGEN_DELAY = 0.8,
	REGEN_SECONDS = 3.5,
	RESTART_FRACTION = 0.3,
	-- Moving means the body really goes at least MOVING_SPEED studs a second across the floor.
	MOVING_SPEED = 4,
	-- Sprinting feet are heard: a noise of SPRINT_NOISE_RADIUS (before the Manager's hearing scale) every
	-- SPRINT_NOISE_INTERVAL seconds while moving at a sprint. Walking stays silent. 10 (was 14): a sprint round a corner
	-- with a lead is not heard, so a juke works; on his heels it still is.
	SPRINT_NOISE_RADIUS = 10,
	SPRINT_NOISE_INTERVAL = 0.7,
	NOISE_SOURCE = "sprint",
	-- Replicated on the Player: stamina 0-1 (rounded to STAMINA_STEP, written only when it changes) and whether they
	-- sprint now.
	STAMINA_ATTRIBUTE = "SprintStamina",
	SPRINTING_ATTRIBUTE = "Sprinting",
	STAMINA_STEP = 0.01,
	-- How often the server steps everyone's stamina.
	TICK = 0.05,
	-- Sprint requests are rate limited (a held key sends two).
	REQUEST_RATE = table.freeze({ maxRequests = 20, windowSeconds = 5 }),
})
