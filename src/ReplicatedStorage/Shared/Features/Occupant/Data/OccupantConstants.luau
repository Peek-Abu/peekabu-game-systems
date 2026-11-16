--!strict
--[=[
	OccupantConstants: Mr. Harlow's tuning, names, placeholder lines and body (Cleanup Crew spec §4 "Mr.
	Harlow", §7). Every number is a tuning hypothesis. The pacing knobs (pressure tiers, party size) live in
	ShiftConstants (spec §4 "Pacing": one constants module). The gestures and the dread table live in
	OccupantGestureConstants and OccupantDreadConstants and are re-exported here unchanged. Static data (spec-exempt).

	@class OccupantConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantDreadConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantDreadConstants)
local OccupantGestureConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantGestureConstants)

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

-- A procedural gesture and its keys (OccupantGestureConstants, re-exported here unchanged).
export type GestureKey = OccupantGestureConstants.GestureKey
export type Gesture = OccupantGestureConstants.Gesture

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
	-- Peripheral vision (behaviours design §10.1): outside the front cone but within PERIPHERAL_ANGLE degrees in all
	-- (±100°), within PERIPHERAL_RANGE studs, with a clear line. Someone there is noticed over GLANCE_SECONDS (min at his
	-- side, max at PERIPHERAL_RANGE; ×GLANCE_CROUCH crouched) while he walks on; out of the zone the count falls back
	-- NOTICE_DECAY seconds a second. A completed glance is a head turn (TURN_*), never an instant chase.
	PERIPHERAL_ANGLE = 200,
	PERIPHERAL_RANGE = 25,
	GLANCE_SECONDS = range(1.5, 2.5),
	GLANCE_CROUCH = 1.4,
	-- The felt presence (§11.7): someone behind him (past PERIPHERAL_ANGLE, his blind back) within FELT_RANGE
	-- studs with a clear line is felt over FELT_SECONDS (×GLANCE_CROUCH crouched), sharing the glance's count;
	-- then the head turn. FELT_RANGE is CERTAIN_RANGE, so the turn may be a slow one.
	FELT_RANGE = 14,
	FELT_SECONDS = 2.5,
	-- The head turn (§10.2, mode `alert`): on a completed glance, or a noise from outside his front cone, he stops dead,
	-- swivels only his head to the point (TURN_SWIVEL: the swivel gesture's own 0.35 s) and holds TURN_HOLD (rolled)
	-- after it lands; then he chases anyone not hidden in the SIGHT_ANGLE cone his head looks down (SIGHT_RANGE), else
	-- investigates the point. The hold is the player's window to hide or break the line.
	TURN_SWIVEL = 0.35,
	-- (2026-10-17, the developer: +0.4 s, was 0.6-1.0, so a player has a real window to duck.)
	TURN_HOLD = range(1.0, 1.4),
	-- A noise while he already searches: no head turn's beat, he runs straight there, but first his head snaps to it for
	-- SEARCH_SNAP seconds (no move meanwhile) so it still reads (the developer, 2026-10-17).
	SEARCH_SNAP = 0.2,
	-- The slow turns (behaviours design §11, approved 2026-10-17; the snap above stays the common case).
	-- §11.1 Which turn. A slow variant needs a target he is certain of: not hidden, a clear line, and within
	-- CERTAIN_RANGE flat studs (the ambush radius) or seen at least CERTAIN_WATCHED seconds a moment ago (Mind.watched,
	-- decaying WATCH_DECAY a second). Never on a breather, never right after another slow turn, at least SLOW_GAP
	-- seconds after the last one.
	CERTAIN_RANGE = 14,
	-- A developer's Workspace attribute (Studio only, fail-closed; OccupantTurnRules.forcedBy): "snap", "knowing" or
	-- "stare" makes every head turn that variant while it is set, skipping the gates, rolls and certainty.
	FORCE_TURN_ATTRIBUTE = "ForceSlowTurn",
	CERTAIN_WATCHED = 0.5,
	SLOW_GAP = 60,
	-- The staring contest (the rarest): once a shift for the whole crew, only with the menace gauge within STARE_MENACE
	-- (tension built, not peaking), on a roll under STARE_CHANCE (Senses.rolls[5]).
	STARE_MENACE = range(20, 70),
	STARE_CHANCE = 0.35,
	-- The knowing turn: once a shift per player, only with menace at most KNOWING_MENACE_MAX, on a roll under
	-- KNOWING_CHANCE (Senses.rolls[6]).
	-- (85 and 0.75 since the 2026-10-17 tuning, §11.7: were 70 and 0.5.)
	KNOWING_MENACE_MAX = 85,
	KNOWING_CHANCE = 0.75,
	-- §11.2 The slow turn: his head comes round over SLOW_TURN_SECONDS (the slowSwivel gesture), his waist leading with
	-- SLOW_WAIST_SHARE of the yaw (all of it by SLOW_WAIST_LEAD of the turn) so the smile comes round last. For the first
	-- SLOW_SETTLE seconds where the target "stands" follows them (time to freeze at the creak).
	SLOW_TURN_SECONDS = OccupantGestureConstants.SLOW_TURN_SECONDS,
	SLOW_WAIST_SHARE = 0.2,
	SLOW_WAIST_LEAD = 0.6,
	SLOW_SETTLE = 0.35,
	-- Meaningful movement (never a camera turn): a flat speed of STILL_SPEED studs/s or more, or a drift of
	-- STILL_DISTANCE studs (3D, so a jump counts) from where they stood.
	STILL_SPEED = 2.5,
	STILL_DISTANCE = 1.25,
	-- Moving mid-turn: his head whips the rest of the way over WHIP_SECONDS (the whip gesture) as the jerk begins.
	WHIP_SECONDS = OccupantGestureConstants.WHIP_SECONDS,
	-- §11.3 The staring contest: after the turn he stares, stock still, for a rolled STARE_CONTEST_SECONDS, then bolts
	-- anyway.
	STARE_CONTEST_SECONDS = range(4, 7),
	-- §11.4 The jerk: his body snaps round to his already-turned head over JERK_SECONDS (ease-out) as the chase starts;
	-- from a chair he pops up with the stand clip at JERK_STAND_SPEED (1.8 s / 8 = 0.225 s).
	JERK_SECONDS = 0.13,
	JERK_STAND_SPEED = 8,
	-- §11.2 The lights during a slow turn or a stare: those within SLOW_FLICKER_RADIUS studs flicker, dark whenever the
	-- flicker noise is under SLOW_FLICKER_THRESHOLD (the usual flicker: FLICKER_RADIUS, -0.1, mostly lit).
	SLOW_FLICKER_RADIUS = 34,
	SLOW_FLICKER_THRESHOLD = 0.15,
	-- Investigate scans for 4 s; search scans for 2 s at last-seen and nearby authored points. Investigate gives up after
	-- GIVE_UP_SECONDS (an unreachable point).
	LOOK_SECONDS = 4,
	SEARCH_SECONDS = 2,
	-- How long he stands still after opening a door in reach, before he walks on.
	DOOR_BEAT_SECONDS = 0.5,
	SEARCH_MAX_SECONDS = 32,
	SEARCH_RADIUS = 36,
	SEARCH_PROBES = 2,
	GIVE_UP_SECONDS = 20,
	-- A walk that goes nowhere (no path from where he stands, or to his goal): standing still on a `goTo` for
	-- STUCK_SECONDS (moving less than STUCK_MOVE flat studs) drops that goal; still stuck after another STUCK_SECONDS, he
	-- is lifted to the nearest route point (OccupantStuckRules; 2026-10-17 audit: patrol legs and steers had no give-up).
	STUCK_SECONDS = 4,
	STUCK_MOVE = 1.5,
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
	-- A hider he found at their spot (the check, a cabinet he opened, a sit-in) may be this much further: his stare's
	-- stand point (STARE_GAP out, beside the spot, or straight out further) is 6-7 studs from the huddle (2026-10-17
	-- audit: a catch refused there looped him back into another stare).
	FOUND_REACH = 3,
	CATCH_COOLDOWN = 1,
	-- After a catch he stands CATCH_HOLD seconds, then walks on; he ignores that player GRACE_SECONDS.
	CATCH_HOLD = 1.5,
	GRACE_SECONDS = 10,
	-- A runner as fast as he is (his chase speed barely beats a sprint) could be chased forever: after
	-- CHASE_GIVE_UP_SECONDS on the same player without a catch (the clock runs on through a search for them) he sighs,
	-- goes back to patrol and ignores that player CHASE_COOLDOWN_SECONDS (their grace), so he does not re-chase at once.
	CHASE_GIVE_UP_SECONDS = 25,
	CHASE_COOLDOWN_SECONDS = 8,
	-- The catch: camera on his face ~1 s (the jumpscare), then the launch. A catch that leaves a life is a hit: down
	-- KNOCKDOWN_SECONDS (Death's knockdown), then up where they landed. The last life's catch kills: ~8 s spectating
	-- (Death's respawn delay), or held down for the shift once knocked out.
	SNAP_SECONDS = 1,
	KNOCKDOWN_SECONDS = 1,
	SPECTATE_SECONDS = 8,
	LAUNCH_SPEED = 45,
	LAUNCH_UP = 35,
	-- He appears this far above his starting route point.
	SPAWN_HEIGHT = 4,
	-- How often his speeds and hearing are refreshed (tier, crew size).
	TUNING_INTERVAL = 1,
	-- Tells: lights within ~26 studs flicker (the mid stage). The heartbeat and the screen mood are the dread's (DREAD).
	FLICKER_RADIUS = 26,
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
	-- The catch's screen: a red, drained flash that still leaves his lit face readable (2026-10-17: was saturation
	-- -0.7, contrast 0.3 and a (255, 120, 120) tint, which with the dread and the lights-out crushed his face to black).
	CATCH_TINT = Color3.fromRGB(255, 172, 166),
	CATCH_SATURATION = -0.35,
	CATCH_CONTRAST = 0.08,
	-- One beat of the chase music (B minor, 144 bpm): the chased player's heartbeat locks to it (DREAD).
	CHASE_BEAT = 60 / 144,
	-- The chase music (round-2 pick B, OccupantChaseMusicSystem): the sting is one bar (4 beats) that resolves into the
	-- loop's downbeat, so the five stems start CHASE_STING_LEAD seconds after it. Intensity 1 (ostinato + low) plays
	-- the whole chase; intensity 2's stems (motif, ticks, pulse) fade in as he closes (DREAD.CHASE_LAYER_FAR / _NEAR,
	-- OccupantTellRules.chaseLayer), moving at most 1 / CHASE_LAYER_SECONDS a second. The stems re-lock
	-- to the ostinato when one drifts CHASE_STEM_DRIFT seconds; the chase's end fades them over
	-- CHASE_MUSIC_FADE seconds.
	CHASE_STING_LEAD = 4 * 60 / 144,
	CHASE_LAYER_SECONDS = 0.6,
	CHASE_STEM_DRIFT = 0.04,
	-- P1 11-14 ("cutting in and out"): the music stays on until the chase on you has been off CHASE_MUSIC_HOLD seconds
	-- (a lost sight line, a target swap and back), then fades out over CHASE_MUSIC_FADE (was 1.5); a chase back inside
	-- the fade brings the same stems back up over CHASE_MUSIC_FADE_IN, no new sting, no restart from bar one.
	CHASE_MUSIC_FADE = 2.5,
	CHASE_MUSIC_FADE_IN = 0.5,
	CHASE_MUSIC_HOLD = 4,
	-- The truck box's PathfindingModifier label (Office builds it; his kind's pathCosts never enter it), and
	-- the tag on the office's ceiling lights (Office builds them; the tells flicker them).
	SAFE_ZONE_LABEL = "SafeZone",
	LIGHT_TAG = "OfficeLight",
	-- Parts his sight ray (and the camera-to-him dread ray) pass through: glass walls Office builds. They stay solid.
	SIGHT_THROUGH_TAG = "SightThrough",
	-- His voiced line (a model attribute: "" when none). Never drawn: since 2026-10-16 nothing shows over his head.
	LINE_ATTRIBUTE = "OccupantLine",
	-- Player-facing name (the Residual company paperwork calls the "Site Supervisor Proxy"); the internals keep `harlow`.
	DISPLAY_NAME = "The Manager",
	-- M3 UI. Public field: the server time a caught player is back on the clock (the roster's "CAUGHT · back 0:06");
	-- cleared on the respawn.
	PUBLIC_CAUGHT_UNTIL = "caughtUntil",
	-- The Rehired card shows from REHIRED_LEAD seconds before the respawn until REHIRED_HOLD seconds after it, the new
	-- character held still meanwhile (OccupantServiceClient), then fades out over REHIRED_FADE as control comes back.
	REHIRED_LEAD = 1.5,
	REHIRED_HOLD = 3,
	REHIRED_FADE = 0.5,
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
	-- The ambush: a player this close with a clear line (or one he sees, or a noise) while he sits (§10.4: never through
	-- a wall); the smile before the Noticing face, the
	-- hold, the stand-up speed (1.8 s clip / 1.5 = 1.2 s). STAND_SECONDS is the clip at 1x; standOffset in OccupantAssets.
	AMBUSH_RADIUS = 14,
	-- The developer's ambush repro (`occupantwork`): the desk he is sent to is at least this far from the caller, so they
	-- can watch him sit before walking up behind him.
	SUMMON_DISTANCE = 20,
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
	-- (3.6 since 2026-10-17, was 1.6: from there his check's fold arced his head through the desk's top; now he folds
	-- clear of it and leans in.)
	STARE_GAP = 3.6,
	-- ...and that far to the side of the spot's centre line, beside the desk's chair rather than in it: on its left (-X,
	-- the knee-hole's open side; a desk's drawer pedestal fills its +X end, where his check's head ended inside it,
	-- 2026-10-17). When furniture stands there (a table beside a supply cabinet), the other side, else straight out
	-- STARE_GAP + STAND_OUT (OccupantDeskUtils.standPoints; the first clear one, OccupantSenseSystem): he is never slid
	-- into furniture.
	STARE_SIDE = -1.9,
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
	-- the hider), typing, the head tipping down (its Calm part), the hold (then always the catch), the head back up,
	-- typing more.
	SIT_IN_CHANCE = 0.35,
	SIT_IN_MAX = 2,
	SIT_IN_GAP = 90,
	SIT_IN_BACK = 0.7,
	SIT_IN_TYPE = range(7, 11),
	TIP_SECONDS = 2.6,
	TIP_CALM = 1.7,
	TIP_HOLD = 1.4,
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
	-- §5 The staged tells (client): stage bands and the far pen click (no PA since 2026-10-16; the near stage's dread
	-- is DREAD's).
	STAGE_FAR = 85,
	STAGE_MID = 45,
	STAGE_NEAR = 25,
	PEN_CLICK = range(9, 16),
	-- The proximity dread and the chase's feel and mix: one table (see DREAD above).
	DREAD = OccupantDreadConstants,
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
	GESTURES = OccupantGestureConstants.GESTURES,
	GESTURE_RELEASE = 0.4,
	TILT_DEGREES = 25,
	TILT_SECONDS = 0.45,
	TILT_SHIVER = 2.5,
	LINES = table.freeze(LINES),
	LINE_VARIANTS = table.freeze(LINE_VARIANTS),
	-- The catch scare's grin over his face (spec §4 "stretched-grin face"; kid-safe cartoon): its billboard,
	-- size in studs, how wide the mouth stretches, teeth, colours (used while the grin image is pending).
	GRIN_NAME = "OccupantGrin",
	GRIN_SIZE = 3.2,
	GRIN_STRETCH = 0.92,
	GRIN_TEETH = 7,
	GRIN_WHITE = Color3.fromRGB(250, 250, 240),
	GRIN_INK = Color3.fromRGB(15, 10, 10),
	-- The monster roster (OccupantKindRegistry): the rig attribute naming its kind (absent = "harlow"), whether a
	-- freeze kind is watched right now, and the UserId its head turns to (0 = nobody).
	KIND_ATTRIBUTE = "OccupantKind",
	FROZEN_ATTRIBUTE = "OccupantFrozen",
	HEAD_TARGET_ATTRIBUTE = "OccupantHeadTarget",
	-- "Freezes while watched" (substitute spec, "Watched is decided on the server"; Bramble): the camera report's rate
	-- and the server's check rate, how old a report may be, how far the camera may sit from the head (max zoom 13) and
	-- the sight cap. Seen = on the player's actual screen (owner 11-14: "the edges dont count"): the report carries the
	-- camera's vertical FOV and the screen's aspect, held to FREEZE_FOV_MIN..MAX degrees and FREEZE_ASPECT_MIN..MAX
	-- (a forged wide screen gains nothing past a real one), and a point counts FREEZE_SCREEN_SLACK past the edge (a
	-- body part's sliver at the very edge of the screen).
	FREEZE_REPORT_INTERVAL = 0.1,
	FREEZE_CHECK_INTERVAL = 0.1,
	FREEZE_REPORT_FRESH = 0.3,
	FREEZE_CAMERA_RANGE = 16,
	FREEZE_RANGE = 80,
	FREEZE_FOV_MIN = 1,
	FREEZE_FOV_MAX = 100,
	FREEZE_ASPECT_MIN = 0.3,
	FREEZE_ASPECT_MAX = 3,
	FREEZE_SCREEN_SLACK = 0.02,
	-- Fairness: after the last watcher looks away he holds this long, then no catch for FREEZE_CATCH_BLOCK more.
	FREEZE_UNFREEZE_BEAT = 0.4,
	FREEZE_CATCH_BLOCK = 0.6,
	-- The owl head: after this long of non-stop watching it swaps to another crew member; a noise maker counts as
	-- "heard" this long; how fast the client turns the head (per second, exponential).
	HEAD_SWAP_SECONDS = 10,
	HEAD_HEARD_SECONDS = 10,
	HEAD_TURN_RATE = 4,
	-- The trail: a feather every FEATHER_SPACING studs it moved unwatched, fading over FEATHER_FADE_SECONDS, at most
	-- FEATHER_MAX at once, checked every FEATHER_INTERVAL.
	FEATHER_SPACING = 3,
	FEATHER_FADE_SECONDS = 20,
	FEATHER_MAX = 60,
	FEATHER_INTERVAL = 0.2,
	FEATHER_COLOR = Color3.fromRGB(92, 168, 84),
	-- The perch (B4, owner 11-14; OccupantPerchRules): the tag on a tall prop's perch part (OfficeBuildSystem). Unseen
	-- PERCH_UNSEEN_SECONDS and nobody within PERCH_CREW_MIN studs, he moves (unseen) onto the unseen perch nearest a
	-- crew member but at least PERCH_NEAR (and at most PERCH_FAR) from them. He drops to the nearest route point when
	-- someone watched him there and looked away, someone comes within PERCH_DROP_RANGE, or after PERCH_HOLD_MAX
	-- seconds; then not again for PERCH_COOLDOWN.
	PERCH_TAG = "OccupantPerch",
	PERCH_UNSEEN_SECONDS = 15,
	PERCH_CREW_MIN = 40,
	PERCH_NEAR = 16,
	PERCH_FAR = 45,
	PERCH_DROP_RANGE = 10,
	PERCH_HOLD_MAX = 20,
	PERCH_COOLDOWN = 30,
	-- (Owner play-check 11-14.) A perch is offered only where his perched body (Senses.perchHeight) fits under the
	-- ceiling with PERCH_HEAD_CLEAR studs to spare, and only with a checked landing PERCH_LANDING_OUT studs past the
	-- prop's edge (a clear line out from over the top and a floor under it), so the drop never goes through a wall.
	PERCH_HEAD_CLEAR = 0.3,
	PERCH_LANDING_OUT = 2.5,
	-- The move up happens in the dark: the server marks the rig (PERCH_FLASH_ATTRIBUTE, a counter, and
	-- PERCH_FLASH_TARGET_ATTRIBUTE, the perch top) and moves him PERCH_DARK_LEAD later. Every client darks the lights
	-- within PERCH_BLACKOUT_RADIUS of where he was and of the perch for PERCH_DARK_SECONDS, then flickers them back on
	-- over PERCH_FLICKER_BACK_SECONDS.
	PERCH_FLASH_ATTRIBUTE = "OccupantPerchFlash",
	PERCH_FLASH_TARGET_ATTRIBUTE = "OccupantPerchFlashAt",
	PERCH_DARK_LEAD = 0.2,
	PERCH_DARK_SECONDS = 0.7,
	PERCH_FLICKER_BACK_SECONDS = 0.45,
	PERCH_BLACKOUT_RADIUS = 30,
	-- The drop's beats (see GESTURES.drop): the fall, the squash, the rise, all of them, and the hop up off the top.
	DROP_FALL_SECONDS = OccupantGestureConstants.DROP_FALL_SECONDS,
	DROP_SQUASH_SECONDS = OccupantGestureConstants.DROP_SQUASH_SECONDS,
	DROP_RISE_SECONDS = OccupantGestureConstants.DROP_RISE_SECONDS,
	DROP_SECONDS = OccupantGestureConstants.DROP_SECONDS,
	DROP_HOP = 1.5,
})
