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

-- Placeholder speech-bubble lines by OccupantTypes.Cue (spec §4 "Voice"; M3 adds the gibberish voice).
local LINES: { [string]: string } = {
	spotted = "Those are COMPANY ASSETS.",
	curious = "Per my last email…",
	caught = "You're FIRED!",
	giveUp = "*sigh*",
	resting = "Fifteen minutes. Union rules.",
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
	REHIRED_TEXT = "Rehired.",
	BODY = table.freeze(BODY),
	LINES = table.freeze(LINES),
})
