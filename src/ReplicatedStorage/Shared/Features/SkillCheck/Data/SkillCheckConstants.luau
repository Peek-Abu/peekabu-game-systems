--!strict
--[=[
	SkillCheckConstants: the closing-ring skill check's tuning (owner-approved idea k1, 2026-11-17: "not like lock pick
	and more like guitar hero - the inner circle is there and moving mouse around moves an icon around that inner
	circle! An outer circle with an opening comes and when it gets to you if icon not in proper opening, it's a fail";
	"Maybe each one gets smaller until pile is cleaned too!"). While a player vacuums a pile on a shift, rings come one
	after another; the opening narrows with the pile's progress; a miss is a loud noise Harlow may hear. Every number is
	a tuning hypothesis. Angles are degrees on the screen, 0 = straight up, growing clockwise. Static data
	(spec-exempt).

	@class SkillCheckConstants
]=]

return table.freeze({
	-- THE launch switch: false starts no rings at all (vacuuming plays exactly as before).
	ENABLED = true,
	-- Seconds the outer ring takes to close in from its start onto the inner circle.
	TRAVEL = 1.2,
	-- Seconds from starting on a pile to its first ring.
	FIRST_DELAY = 0.35,
	-- Seconds between one ring being judged and the next one starting (while still on a pile).
	BETWEEN = 0.4,
	-- The opening's width (degrees) at a pile's start and at its end: it narrows straight from one to the other as the
	-- pile's progress rises, so the last ring of a pile is the hardest.
	WIDTH_START = 120,
	WIDTH_END = 55,
	-- Each new opening sits at least this far round from the last one (degrees), so it is never already lined up.
	MIN_SHIFT = 90,
	-- Extra degrees either side of the opening the server still counts as a hit (the icon's own size, and the frame
	-- between the client's sample and its send).
	TOLERANCE = 8,
	-- A report is judged only when the server receives it from REPORT_EARLY seconds before the ring arrives to
	-- REPORT_LATE seconds after (the trip up from the client); none in that window is a miss.
	REPORT_EARLY = 0.25,
	REPORT_LATE = 0.6,
	-- The rate limit on reports (a ring every ~1.6 s at most; room for a burst).
	REPORT_LIMIT = table.freeze({ maxRequests = 6, windowSeconds = 5 }),
	-- A miss: a noise at the player this loud (studs before Harlow's hearing scale; the vacuum's own pulse is
	-- VacuumConstants.NOISE_RADIUS, 40), from this source (not a Quiet source: the stat does not soften it).
	MISS_NOISE_RADIUS = 70,
	MISS_NOISE_SOURCE = "skillcheck",
	-- Seconds between the server's checks of who is vacuuming (rings start and expire on this beat).
	STEP_INTERVAL = 0.05,
	-- The client's feedback sounds (existing UI cues, UIAssets.sounds): the miss's dull clunk and the hit's light tick.
	MISS_SOUND = "uiError",
	HIT_SOUND = "uiHover",
	-- Input: a gamepad stick pushed less than this far keeps the icon where it is; a touch counts only within this many
	-- inner radii of the ring's centre (so the thumbstick and the vacuum button never steer it).
	STICK_DEADZONE = 0.35,
	TOUCH_REACH = 3,
	-- The hint under the first rings a player sees this session.
	HINT = "Line it up!",
	HINT_RINGS = 2,
})
