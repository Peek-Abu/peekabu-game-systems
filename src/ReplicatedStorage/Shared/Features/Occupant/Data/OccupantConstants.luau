--!strict
--[=[
	OccupantConstants: Mr. Harlow's tuning, names, placeholder lines and body (Cleanup Crew spec §4 "Mr.
	Harlow", §7). Every number is a tuning hypothesis. The pacing knobs (pressure tiers, party size) live in
	ShiftConstants (spec §4 "Pacing": one constants module). Static data (spec-exempt).

	@class OccupantConstants
]=]

export type Body = {
	height: number,
	width: number,
	depth: number,
	head: number,
	suit: Color3,
	shirt: Color3,
	skin: Color3,
}

-- "A tall, too-thin suited R15 rig built from a HumanoidDescription in code" (spec §7).
local BODY: Body = {
	height = 1.3,
	width = 0.7,
	depth = 0.65,
	head = 0.9,
	suit = Color3.fromRGB(38, 40, 48),
	shirt = Color3.fromRGB(205, 205, 195),
	skin = Color3.fromRGB(214, 200, 180),
}

-- The fallback speech-bubble line per OccupantTypes.Cue (spec §4 "Voice"); LINE_VARIANTS holds the variants, and the
-- gibberish voice is played by the client OccupantPresenceSystem.
local LINES: { [string]: string } = {
	spotted = "Those are COMPANY ASSETS.",
	curious = "Per my last email…",
	caught = "You're FIRED!",
	giveUp = "*sigh*",
	resting = "Fifteen minutes. Union rules.",
}

-- His lines per cue (spec §4 "Voice": the speech bubble's line; the spec's three are kept). The server picks one
-- per cue, never the same twice running (OccupantFeedbackUtils.pickLine); LINES stays the fallback.
local LINE_VARIANTS: { [string]: { string } } = {
	spotted = { "Those are COMPANY ASSETS.", "Put that BACK.", "This is THEFT.", "Who authorised this?!" },
	curious = { "Per my last email…", "Who's there? Accounting?", "I heard that.", "Is someone in my office?" },
	caught = { "You're FIRED!" },
	giveUp = { "*sigh*" },
	resting = { "Fifteen minutes. Union rules.", "Don't touch my stapler.", "Coffee. Then performance reviews." },
}

return table.freeze({
	-- The NPC kind, and the tag the client's tells find him by.
	NPC_KIND = "harlow",
	TAG = "Occupant",
	-- Replicated attributes on his model: his mode, and the UserId he is chasing (0 = nobody).
	MODE_ATTRIBUTE = "OccupantMode",
	TARGET_ATTRIBUTE = "OccupantTarget",
	-- Speeds (spec: patrol 10, chase 15); tiers and party size adjust them (OccupantTuningFormulas).
	PATROL_SPEED = 10,
	CHASE_SPEED = 15,
	-- Sight: ~60 studs, a 100° cone, line of sight.
	SIGHT_RANGE = 60,
	SIGHT_ANGLE = 100,
	-- Investigate: look around ~4 s at the noise; search: ~6 s at the last-seen point; either gives up after
	-- GIVE_UP_SECONDS (an unreachable point).
	LOOK_SECONDS = 4,
	SEARCH_SECONDS = 6,
	GIVE_UP_SECONDS = 20,
	-- Close enough to a point to count as there (flat studs).
	REACHED_DISTANCE = 3,
	-- While looking around he sweeps ±LOOK_SWEEP degrees at LOOK_RATE radians of phase per second.
	LOOK_SWEEP = 70,
	LOOK_RATE = 1.2,
	-- Catch at ~4 studs (the server re-checks with CATCH_SLACK of tolerance); one try per CATCH_COOLDOWN.
	CATCH_RANGE = 4,
	CATCH_SLACK = 1,
	CATCH_COOLDOWN = 1,
	-- After a catch he stands CATCH_HOLD seconds, then walks on; he ignores that player GRACE_SECONDS.
	CATCH_HOLD = 1.5,
	GRACE_SECONDS = 10,
	-- The catch: camera on his face ~0.6 s, then the launch; ~8 s spectating (Death's respawn delay).
	SNAP_SECONDS = 0.6,
	SPECTATE_SECONDS = 8,
	LAUNCH_SPEED = 45,
	LAUNCH_UP = 35,
	-- He appears this far above his starting route point.
	SPAWN_HEIGHT = 4,
	-- How often his speeds and hearing are refreshed (tier, crew size).
	TUNING_INTERVAL = 1,
	-- Tells: lights within ~20 studs flicker; the heartbeat within HEARTBEAT_RANGE, one beat per BEAT_SLOW
	-- seconds at the edge down to BEAT_FAST up close.
	FLICKER_RADIUS = 20,
	HEARTBEAT_RANGE = 40,
	BEAT_SLOW = 1,
	BEAT_FAST = 0.45,
	-- A catch kills the lights within LIGHTS_OUT_RADIUS for LIGHTS_OUT_SECONDS; a tier rise flickers every
	-- light for TIER_FLICKER_SECONDS. The client re-checks the tells every TELL_INTERVAL.
	LIGHTS_OUT_RADIUS = 30,
	LIGHTS_OUT_SECONDS = 2.5,
	TIER_FLICKER_SECONDS = 1.5,
	TELL_INTERVAL = 0.05,
	SPEECH_SECONDS = 3,
	-- The catch camera (above Death's spectate mode at 50) and its screen effect.
	CAMERA_PRIORITY = 70,
	CATCH_FOV = 50,
	CATCH_TRAUMA = 0.6,
	CATCH_TINT = Color3.fromRGB(255, 120, 120),
	HEARTBEAT_TINT = Color3.fromRGB(255, 150, 150),
	-- The loading bay's PathfindingModifier label (Office builds it; his kind's pathCosts never enter it), and
	-- the tag on the office's ceiling lights (Office builds them; the tells flicker them).
	SAFE_ZONE_LABEL = "SafeZone",
	LIGHT_TAG = "OfficeLight",
	-- His billboards (placeholders).
	CUE_NAME = "OccupantCue",
	SPEECH_NAME = "OccupantSpeech",
	DISPLAY_NAME = "Mr. Harlow",
	-- M3 UI. Public field: the server time a caught player is back on the clock (the roster's "CAUGHT · back 0:06");
	-- cleared on the respawn.
	PUBLIC_CAUGHT_UNTIL = "caughtUntil",
	-- The Rehired card shows from REHIRED_LEAD seconds before the respawn until REHIRED_HOLD seconds after it.
	REHIRED_LEAD = 1.5,
	REHIRED_HOLD = 3,
	-- The incident report's room when the catch happened outside every room.
	CATCH_ROOM_FALLBACK = "the office",
	BODY = table.freeze(BODY),
	LINES = table.freeze(LINES),
	LINE_VARIANTS = table.freeze(LINE_VARIANTS),
	-- His speech bubble as a memo (spec §7 "typewriter type"): paper, ink, a thin border; the client types each
	-- line out at TYPE_RATE characters a second.
	SPEECH_FONT = Enum.Font.SpecialElite,
	SPEECH_PAPER = Color3.fromRGB(248, 243, 226),
	SPEECH_INK = Color3.fromRGB(34, 30, 26),
	SPEECH_BORDER = Color3.fromRGB(70, 60, 46),
	TYPE_RATE = 28,
	-- Footsteps: one per STRIDE studs walked, clamped to STEP_MIN..STEP_MAX seconds; none below STEP_MIN_SPEED.
	STRIDE = 4.5,
	STEP_MIN_SPEED = 2,
	STEP_MIN = 0.28,
	STEP_MAX = 0.8,
	-- The catch scare's grin over his face (spec §4 "stretched-grin face"; kid-safe cartoon): its billboard,
	-- size in studs, how wide the mouth stretches, teeth, colours (used while the grin image is pending).
	GRIN_NAME = "OccupantGrin",
	GRIN_SIZE = 3.2,
	GRIN_STRETCH = 0.92,
	GRIN_TEETH = 7,
	GRIN_WHITE = Color3.fromRGB(250, 250, 240),
	GRIN_INK = Color3.fromRGB(15, 10, 10),
})
