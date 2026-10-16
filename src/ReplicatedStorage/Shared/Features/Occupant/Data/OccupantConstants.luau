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

-- The fallback line per OccupantTypes.Cue (spec §4 "Voice"; never shown since 2026-10-16, it picks his gibberish clip);
-- LINE_VARIANTS holds the variants, and the voice is played by the client OccupantPresenceSystem.
local LINES: { [string]: string } = {
	spotted = "Those are COMPANY ASSETS.",
	curious = "Per my last email…",
	caught = "You're FIRED!",
	giveUp = "*sigh*",
	resting = "Fifteen minutes. Union rules.",
	ambush = "Can I HELP you?",
	sitIn = "Now… where was I.",
}

-- His lines per cue (spec §4 "Voice": the speech bubble's line; the spec's three are kept). The server picks one
-- per cue, never the same twice running (OccupantFeedbackUtils.pickLine); LINES stays the fallback.
local LINE_VARIANTS: { [string]: { string } } = {
	spotted = { "Those are COMPANY ASSETS.", "Put that BACK.", "This is THEFT.", "Who authorised this?!" },
	curious = { "Per my last email…", "Who's there? Accounting?", "I heard that.", "Is someone in my office?" },
	caught = { "You're FIRED!" },
	giveUp = { "*sigh*" },
	resting = { "Fifteen minutes. Union rules.", "Don't touch my stapler.", "Coffee. Then performance reviews." },
	ambush = { "Can I HELP you?", "We don't run in the office.", "Do you have an appointment?" },
	sitIn = { "Now… where was I.", "Just a few more reports." },
}

-- A procedural gesture laid over his animation (OccupantGestureFormulas): how long it takes to settle, and each
-- joint's extra rotation in degrees (X pitch, Y yaw, Z roll; negative X bends forward).
export type Gesture = { seconds: number, joints: { [string]: Vector3 } }

local GESTURES: { [string]: Gesture } = {
	-- The ambush: the head snaps round to the point on the long neck (the yaw is aimed live; this is its timing).
	swivel = { seconds = 0.35, joints = {} },
	-- The stare's check: he folds double at the waist (he is far too tall to stoop) and his head hangs down, tipped
	-- sideways, at the mouth of the spot (tuned live against the built desk).
	peek = { seconds = 0.9, joints = { Waist = Vector3.new(-150, 0, 0), Neck = Vector3.new(150, 0, 90) } },
	-- The sit-in: from the chair he folds forward over his knees and his head comes in under the desk's lip, upside
	-- down and facing the hider (tuned live: the head ends 0.6 studs under the front edge, just off the floor).
	under = { seconds = 2.6, joints = { Waist = Vector3.new(-98, 0, 0), Neck = Vector3.new(98, 0, 180) } },
}

export type Range = { min: number, max: number }
local function range(min: number, max: number): Range
	return table.freeze({ min = min, max = max })
end

return table.freeze({
	-- The NPC kind, and the tag the client's tells find him by.
	NPC_KIND = "harlow",
	TAG = "Occupant",
	-- Replicated attributes on his model: his mode, and the UserId he is chasing (0 = nobody).
	MODE_ATTRIBUTE = "OccupantMode",
	TARGET_ATTRIBUTE = "OccupantTarget",
	-- Pursuit tuning: patrol 10, chase 20; tiers and party size adjust them (OccupantTuningFormulas).
	PATROL_SPEED = 10,
	CHASE_SPEED = 20,
	-- Sight: ~60 studs, a 100° cone, line of sight (seen at once). Straight ahead he also sees far down a clear line:
	-- out to LONG_SIGHT_RANGE in a LONG_SIGHT_ANGLE cone, noticed over NOTICE_SECONDS (min at SIGHT_RANGE, max at
	-- LONG_SIGHT_RANGE) while he stops and turns his head to look; then the chase. A noticing that loses its player falls
	-- back NOTICE_DECAY seconds a second. So a chase can start far away, with room to run or hide.
	SIGHT_RANGE = 60,
	SIGHT_ANGLE = 100,
	LONG_SIGHT_RANGE = 125,
	LONG_SIGHT_ANGLE = 40,
	NOTICE_SECONDS = range(0.35, 1.4),
	NOTICE_DECAY = 2,
	-- Investigate scans for 4 s; search scans for 2 s at last-seen and nearby authored points. Investigate gives up after
	-- GIVE_UP_SECONDS (an unreachable point).
	LOOK_SECONDS = 4,
	SEARCH_SECONDS = 2,
	SEARCH_MAX_SECONDS = 32,
	SEARCH_RADIUS = 36,
	SEARCH_PROBES = 2,
	GIVE_UP_SECONDS = 20,
	-- The loading bay is no longer safe (only the truck's box is): he may patrol, chase and investigate in it, but after
	-- BAY_LINGER_SECONDS there with nobody in sight he walks out and keeps out of it BAY_COOLDOWN_SECONDS, so he never
	-- body-blocks the truck's ramp.
	BAY_LINGER_SECONDS = 8,
	BAY_COOLDOWN_SECONDS = 20,
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
	-- The catch: camera on his face ~1 s (the jumpscare), then the launch; ~8 s spectating (Death's respawn delay).
	SNAP_SECONDS = 1,
	SPECTATE_SECONDS = 8,
	LAUNCH_SPEED = 45,
	LAUNCH_UP = 35,
	-- He appears this far above his starting route point.
	SPAWN_HEIGHT = 4,
	-- How often his speeds and hearing are refreshed (tier, crew size).
	TUNING_INTERVAL = 1,
	-- Tells: lights within ~26 studs flicker (the mid stage); the heartbeat within HEARTBEAT_RANGE, one beat per BEAT_SLOW
	-- seconds at the edge down to BEAT_FAST up close.
	FLICKER_RADIUS = 26,
	HEARTBEAT_RANGE = 25,
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
	-- The chase on you (2026-10-16: with no "!" over his head the chase must be unmissable by sound and screen alone):
	-- your heartbeat races at one beat per CHASE_BEAT seconds however far he is, and the screen pulses with it, soft
	-- red (CHASE_TINT): up over CHASE_RISE seconds, never below CHASE_FLOOR of full between beats, fading out over
	-- CHASE_FADE seconds once the chase ends (OccupantTellRules.chasePulse). Kept subtle (kid-friendly).
	CHASE_BEAT = 0.36,
	CHASE_RISE = 0.2,
	CHASE_FLOOR = 0.35,
	CHASE_FADE = 1.5,
	CHASE_TINT = Color3.fromRGB(255, 165, 165),
	-- The truck box's PathfindingModifier label (Office builds it; his kind's pathCosts never enter it), and
	-- the tag on the office's ceiling lights (Office builds them; the tells flicker them).
	SAFE_ZONE_LABEL = "SafeZone",
	LIGHT_TAG = "OfficeLight",
	-- His voiced line (a model attribute: "" when none). Never drawn: since 2026-10-16 nothing shows over his head.
	LINE_ATTRIBUTE = "OccupantLine",
	-- Player-facing name (the Residual company paperwork calls the "Site Supervisor Proxy"); the internals keep `harlow`.
	DISPLAY_NAME = "The Manager",
	-- M3 UI. Public field: the server time a caught player is back on the clock (the roster's "CAUGHT · back 0:06");
	-- cleared on the respawn.
	PUBLIC_CAUGHT_UNTIL = "caughtUntil",
	-- The Rehired card shows from REHIRED_LEAD seconds before the respawn until REHIRED_HOLD seconds after it.
	REHIRED_LEAD = 1.5,
	REHIRED_HOLD = 3,
	-- The incident report's room when the catch happened outside every room.
	CATCH_ROOM_FALLBACK = "the office",
	BODY = table.freeze(BODY),
	-- Behaviour set (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-design.md). Ranges are seconds
	-- (or studs) rolled per use.
	-- §1 Desk work: the first break after he clocks in, the gap between breaks, how long he types; the desk "near the
	-- crew" chance and band (studs from the nearest crew member, PICK_IDEAL wins), "elsewhere" distance, and how close a
	-- standing player rules a desk out.
	WORK_FIRST = range(20, 40),
	WORK_GAP = range(35, 70),
	WORK_SECONDS = range(10, 22),
	PICK_NEAR_CHANCE = 0.55,
	PICK_NEAR = range(18, 45),
	PICK_IDEAL = 30,
	PICK_FAR = 45,
	PICK_CLEAR = 10,
	-- The ambush: a player this close (or one he sees, or a noise) while he sits; the smile before the Noticing face, the
	-- hold, the stand-up speed (1.8 s clip / 1.5 = 1.2 s). STAND_SECONDS is the clip at 1x; standOffset in OccupantAssets.
	AMBUSH_RADIUS = 14,
	AMBUSH_SMILE = 0.4,
	AMBUSH_HOLD = 1.1,
	AMBUSH_STAND_SPEED = 1.5,
	STAND_SECONDS = 1.8,
	-- Standing up, his root ends at least this far (flat studs) from the desk's footprint (OccupantDeskUtils.standUp):
	-- his body's half-width and a margin, so he is never left inside or behind the desk.
	STAND_CLEAR = 1.6,
	-- §2 The stare-down: the gap from the spot's front edge to where he stands, how long he stares (known / suspected),
	-- the check's odds, the bend before the catch, the startle, the noise radius around the spot, the suspicion radius
	-- around a heard noise, how long a spot is left alone after he walks away. The check's odds follow how far away he
	-- was when he saw you go in (2026-10-16): CHECK_NEAR_CHANCE within CHECK_NEAR studs, falling to CHECK_FAR_CHANCE at
	-- CHECK_FAR and beyond (there it is only a suspicion: a short stare), plus CHECK_PER_SECOND per second he had eyes on
	-- you (fading out with the distance), capped at CHECK_MAX. HUNCH_CHECK: he lost his chase near a spot without seeing
	-- where you went, stares at it a moment, and looks on this roll.
	STARE_GAP = 1.6,
	-- ...and that far to the side of the spot's centre line, beside the desk's chair rather than in it. When furniture
	-- stands there (a table beside a supply cabinet), the other side, else straight out STARE_GAP + STAND_OUT
	-- (OccupantDeskUtils.standPoints; the first clear one, OccupantSenseSystem): he is never slid into furniture.
	STARE_SIDE = 1.9,
	STAND_OUT = 1.5,
	STARE_SECONDS = range(4, 10),
	SUSPECT_SECONDS = range(2, 4),
	CHECK_NEAR = 12,
	CHECK_FAR = 40,
	CHECK_NEAR_CHANCE = 0.8,
	CHECK_FAR_CHANCE = 0.1,
	CHECK_PER_SECOND = 0.03,
	CHECK_MAX = 0.9,
	HUNCH_CHECK = 0.12,
	CHECK_SECONDS = 1.1,
	-- A secure supply cabinet: he cannot look in casually. He opens it (OPEN_SECONDS: the handle, then the door) only
	-- after a noise at it, or when he saw you go in within OPEN_RADIUS (and the check roll says so); otherwise he stares
	-- a moment and leaves. Never on a hunch.
	OPEN_SECONDS = 2.2,
	OPEN_RADIUS = 14,
	-- On the way to a spot's stand point: once within STAND_NEAR studs for STAND_SETTLE seconds he plants there (the
	-- slide does the rest) instead of circling a stand point the path cannot quite reach.
	STAND_NEAR = 6,
	STAND_SETTLE = 0.8,
	STARTLE_SECONDS = 0.7,
	STARE_NOISE_RADIUS = 10,
	SUSPECT_RADIUS = 10,
	CLEARED_SECONDS = 25,
	-- Seconds of sight remembered per player decay at this rate once he loses them (per second).
	WATCH_DECAY = 0.5,
	-- §3 Sitting at the desk you hide under: the roll, the per-shift cap and gap, how far back he sits (knees clear of
	-- the hider), typing, the head tipping down (its Calm part), the hold, the catch odds, the head back up, typing more.
	SIT_IN_CHANCE = 0.35,
	SIT_IN_MAX = 2,
	SIT_IN_GAP = 90,
	SIT_IN_BACK = 0.7,
	SIT_IN_TYPE = range(7, 11),
	TIP_SECONDS = 2.6,
	TIP_CALM = 1.7,
	TIP_HOLD = 1.4,
	SIT_IN_CATCH = 0.5,
	TIP_BACK = 1,
	TYPE_MORE = 2,
	-- §4 The director: steer intervals (crew / solo, less per tier, overtime), the first steer, the spread round the
	-- crew member, the breathers, the noise radius he still follows in a breather, the menace gauge's rates.
	STEER_CREW = 28,
	STEER_SOLO = 36,
	STEER_PER_TIER = 4,
	STEER_OVERTIME_CREW = 16,
	STEER_OVERTIME_SOLO = 22,
	STEER_FIRST = range(15, 30),
	STEER_SPREAD = range(12, 20),
	STEER_MIN = 8,
	BREATHER_CREW = range(30, 60),
	BREATHER_SOLO = range(40, 60),
	BREATHER_PER_TIER = 5,
	BREATHER_OVERTIME = range(15, 25),
	BREATHER_HEARING = 20,
	MENACE_MAX = 100,
	MENACE_CHASE = 10,
	MENACE_STARE = 6,
	MENACE_NEAR = 3,
	MENACE_NEAR_RADIUS = 18,
	MENACE_SPOTTED = 15,
	MENACE_CATCH = 45,
	MENACE_DECAY = 2,
	-- §5 The staged tells (client): stage bands, the far pen click, the near dread swell (no PA since 2026-10-16).
	STAGE_FAR = 85,
	STAGE_MID = 45,
	STAGE_NEAR = 25,
	PEN_CLICK = range(9, 16),
	DREAD_FADE = 1.5,
	-- Model attributes the client reads: his phase, his gesture and its target, and the catch tilt.
	PHASE_ATTRIBUTE = "OccupantPhase",
	GESTURE_ATTRIBUTE = "OccupantGesture",
	GESTURE_TARGET_ATTRIBUTE = "OccupantGestureTarget",
	TILT_ATTRIBUTE = "OccupantTilt",
	-- §6 The jumpscare camera: in front of his face plate, its FOV, the head tilt.
	JUMPSCARE_DISTANCE = 1.9,
	JUMPSCARE_FOV = 38,
	-- The hider's reveal: while he bends to look under their spot (or tips his head under the desk they hide under),
	-- their camera draws back into the spot (to their own huddled body, hidden from them) and turns to his face (above
	-- the peek camera, below the catch's jumpscare).
	REVEAL_FOV = 55,
	REVEAL_PRIORITY = 60,
	-- The gestures, how fast one lets go, and the catch's head tilt (degrees of roll, seconds, shiver).
	GESTURES = table.freeze(GESTURES),
	GESTURE_RELEASE = 0.4,
	TILT_DEGREES = 25,
	TILT_SECONDS = 0.45,
	TILT_SHIVER = 2.5,
	LINES = table.freeze(LINES),
	LINE_VARIANTS = table.freeze(LINE_VARIANTS),
	-- Footsteps: one per STRIDE studs walked, clamped to STEP_MIN..STEP_MAX seconds; none below STEP_MIN_SPEED.
	STRIDE = 4.5,
	STEP_MIN_SPEED = 2,
	STEP_MIN = 0.28,
	STEP_MAX = 0.8,
	-- His footsteps land louder as he speeds up: x1 at his walk (STEP_WALK_SPEED) up to STEP_RUN_VOLUME at his chase run
	-- (STEP_RUN_SPEED), so the crew near a chase hears him running (OccupantFeedbackUtils.footstepVolume).
	STEP_WALK_SPEED = 10,
	STEP_RUN_SPEED = 20,
	STEP_RUN_VOLUME = 1.6,
	-- The catch scare's grin over his face (spec §4 "stretched-grin face"; kid-safe cartoon): its billboard,
	-- size in studs, how wide the mouth stretches, teeth, colours (used while the grin image is pending).
	GRIN_NAME = "OccupantGrin",
	GRIN_SIZE = 3.2,
	GRIN_STRETCH = 0.92,
	GRIN_TEETH = 7,
	GRIN_WHITE = Color3.fromRGB(250, 250, 240),
	GRIN_INK = Color3.fromRGB(15, 10, 10),
})
