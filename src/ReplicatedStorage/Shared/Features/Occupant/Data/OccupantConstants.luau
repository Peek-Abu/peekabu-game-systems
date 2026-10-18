--!strict
--[=[
	OccupantConstants: Mr. Harlow's tuning, names, placeholder lines and body (Cleanup Crew spec §4 "Mr.
	Harlow", §7). Every number is a tuning hypothesis. The pacing knobs (pressure tiers, party size) live in
	ShiftConstants (spec §4 "Pacing": one constants module). Static data (spec-exempt).

	@class OccupantConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

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
--
-- A keyed gesture (`keys`) follows a path instead of one straight blend: each key is reached at `at` (0..1 of
-- `seconds`, smoothstepped between keys) with its joints and `back`, how far his whole body is drawn back (studs along
-- his root's back, the Root joint; negative leans him in; a seated body takes its chair along on every client). `exit` is the path back to
-- rest over `exitSeconds`, from the last key, whatever he does next. (2026-10-17: the straight blends arced his head
-- over the desk and down through its top, in view of the hider; the paths below were sampled against the desk and
-- table art for every frame and touch nothing: OccupantClearanceSystem still fades, for the hider only, any part of
-- their spot his body meets where a wall stops him drawing back.)
export type GestureKey = { at: number, back: number, joints: { [string]: Vector3 } }
export type Gesture = {
	seconds: number,
	joints: { [string]: Vector3 },
	keys: { GestureKey }?,
	exit: { GestureKey }?,
	exitSeconds: number?,
}

local function key(at: number, back: number, joints: { [string]: Vector3 }): GestureKey
	return table.freeze({ at = at, back = back, joints = joints })
end

-- At rest (no extra rotation).
local REST: { [string]: Vector3 } = table.freeze({})
-- The sit-in's fold: over his knees, his head upside down facing the hider.
local UNDER_FOLD: { [string]: Vector3 } =
	table.freeze({ Waist = Vector3.new(-98, 0, 0), Neck = Vector3.new(98, 0, 180) })
-- The stare's check: folded double (he is far too tall to stoop), his head hanging tipped sideways, toward the spot's
-- centre line: from its -X side (PEEK_FOLD) or, mirrored, its +X side (PEEK_FOLD_MIRROR). Tipped the other way, from a
-- desk's +X side, his head ended behind its drawer pedestal.
local PEEK_FOLD: { [string]: Vector3 } =
	table.freeze({ Waist = Vector3.new(-150, 0, 0), Neck = Vector3.new(150, 0, 90) })
local PEEK_FOLD_MIRROR: { [string]: Vector3 } =
	table.freeze({ Waist = Vector3.new(-150, 0, 0), Neck = Vector3.new(150, 0, -90) })

-- The slow head turn and the whip that finishes one in a hurry (behaviours design §11): their seconds, shared with the
-- brain's timing below.
local SLOW_TURN_SECONDS = 2.0
local WHIP_SECONDS = 0.15

local GESTURES: { [string]: Gesture } = {
	-- The ambush: the head snaps round to the point on the long neck (the yaw is aimed live; this is its timing).
	swivel = { seconds = 0.35, joints = {} },
	-- The slow turn (§11.2): the same aimed yaw, smootherstepped over SLOW_TURN_SECONDS, the waist leading
	-- (SLOW_WAIST_SHARE); and the whip that carries a turn the rest of the way over WHIP_SECONDS when the player moves.
	-- OccupantGestureSystem carries one turn fraction across the two.
	slowSwivel = { seconds = SLOW_TURN_SECONDS, joints = {} },
	whip = { seconds = WHIP_SECONDS, joints = {} },
	-- The stare's check, from beside the knee-hole (STARE_SIDE, STARE_GAP out: far enough that the fold clears the
	-- top): the fold, then he leans in 1.5 studs so his face hangs at the mouth of the spot, just off its front edge.
	peek = {
		seconds = 1,
		joints = PEEK_FOLD,
		keys = { key(0.6, 0, PEEK_FOLD), key(1, -1.5, PEEK_FOLD) },
		exit = { key(0.4, 0, PEEK_FOLD), key(1, 0, REST) },
		exitSeconds = 0.6,
	},
	-- The same from the spot's other side (Spot.side > 0), his head tipped the other way.
	peekMirror = {
		seconds = 1,
		joints = PEEK_FOLD_MIRROR,
		keys = { key(0.6, 0, PEEK_FOLD_MIRROR), key(1, -1.5, PEEK_FOLD_MIRROR) },
		exit = { key(0.4, 0, PEEK_FOLD_MIRROR), key(1, 0, REST) },
		exitSeconds = 0.6,
	},
	-- The sit-in: he rolls his chair back, folds forward over his knees with his head dropping in front of the desk's
	-- edge, then rolls in so his head comes in under the lip, upside down and facing the hider (it ends 0.5 studs
	-- back, its face just inside the edge). Out (TIP_BACK) the same way in reverse.
	under = {
		seconds = 2.6,
		joints = UNDER_FOLD,
		keys = { key(0.25, 2.8, REST), key(0.7, 2.8, UNDER_FOLD), key(1, 0.5, UNDER_FOLD) },
		exit = { key(0.3, 2.8, UNDER_FOLD), key(0.8, 2.8, REST), key(1, 0, REST) },
		exitSeconds = 1,
	},
}

export type Range = { min: number, max: number }
local function range(min: number, max: number): Range
	return table.freeze({ min = min, max = max })
end

type DreadLook = OccupantTypes.DreadLook

local function look(values: DreadLook): DreadLook
	return table.freeze(values)
end

--[=[
	THE dread table (2026-10-17 feedback: "getting chased doesn't feel scary", "him nearby should have screen effects or
	heartbeats or both"). Every knob of the proximity dread and the chase's feel and mix (OccupantDreadFormulas,
	OccupantDreadSystem, OccupantChaseMusicSystem). Kid-safe: nothing strobes, the vignette never closes the view, and
	every change eases. No markers over him: all of it is screen mood and sound.
]=]
local DREAD = {
	-- Distance (studs) where the dread starts, and where it is full. Beyond RANGE_FAR nothing shows.
	RANGE_FAR = 60,
	RANGE_FULL = 20,
	-- With no line of sight to his head his distance counts this many times farther (walls take the edge off).
	OCCLUDED_SCALE = 1.6,
	-- The line-of-sight ray is re-cast this often (s), and a change in sight blends in over SIGHT_EASE (s).
	SIGHT_INTERVAL = 0.15,
	SIGHT_EASE = 0.5,
	-- "Sees you or hunting" never shows weaker than this share of the aware look, however far he is.
	AWARE_FLOOR = 0.55,
	-- A crewmate chased within CREW_RANGE studs of you (or of the crewmate you spectate) gives you the crew look,
	-- weighted from 1 next to them down to CREW_FLOOR at the edge.
	CREW_RANGE = 45,
	CREW_FLOOR = 0.4,
	-- How fast the look follows its target (1/s, exponential): it rises quickly and breathes out slowly after an escape.
	RISE_SHARPNESS = 3,
	FALL_SHARPNESS = 1.1,
	-- Heartbeat seconds per beat: near ramps BEAT_NEAR_SLOW (at RANGE_FAR) to BEAT_NEAR_FAST (at RANGE_FULL); aware and
	-- crew beat at their own rates. The chase's beat is the music's (CHASE_BEAT, locked to the stems' TimePosition).
	BEAT_NEAR_SLOW = 1.15,
	BEAT_NEAR_FAST = 0.7,
	BEAT_AWARE = 0.55,
	BEAT_CREW = 0.62,
	-- A slow turn or a stare (behaviours design §11.2): the aware stage at full strength, beating faster.
	BEAT_SLOW = 0.5,
	-- The heartbeat sound's volumeScale = look.heart * HEART_GAIN (harlowHeartbeat is registered at 0.8). Measured live
	-- 2026-10-17 in a chase at ~19 studs (RMS of PlaybackLoudness x Volume x group volume): the old heartbeat sat
	-- ~19 dB over the old chase music; at 0.75 (chase heart 0.65-0.8) it sits ~5 dB over the louder music.
	HEART_GAIN = 0.75,
	-- A pulse peaks on the beat and is gone PULSE_WIDTH of the way to the next (a quick attack, eased decay).
	PULSE_WIDTH = 0.45,
	-- The colour the beat pulses toward (multiplied into the screen tint), kept soft.
	PULSE_TINT = Color3.fromRGB(255, 150, 150),
	-- The edge fringe's two tints (a red and a cyan copy of the vignette pushed apart on the beat: the chromatic split).
	EDGE_RED = Color3.fromRGB(255, 70, 70),
	EDGE_CYAN = Color3.fromRGB(70, 230, 255),
	-- How far (screen scale) the edge fringe's copies spread at a full pulse.
	EDGE_SPREAD = 0.035,
	-- The vignette is dark ink, never black, at most VIGNETTE_MAX opaque at the edge.
	VIGNETTE_COLOR = Color3.fromRGB(8, 4, 10),
	VIGNETTE_MAX = 0.85,
	-- How much the vignette tightens (screen scale shrink) at full strength.
	VIGNETTE_TIGHTEN = 0.12,
	-- The grain's tile size (pixels) and its opacity at full strength.
	GRAIN_TILE = 180,
	GRAIN_MAX = 0.22,
	-- His footfalls shake your camera (trauma, camera-setting scaled) within SHAKE_RANGE studs while he sees you or
	-- chases you: SHAKE_TRAUMA at his feet, 0 at the range.
	SHAKE_RANGE = 22,
	SHAKE_TRAUMA = 0.16,
	-- The ambience EQ: the duck on every band, and the muffle on the highs (the mids take MUFFLE_MID of it). Applied to
	-- the Ambient group and to every other Music-group sound (never to his sounds, the chase stems or the dread loop).
	MUFFLE_MID = 0.35,
	-- The chase music's stems play this much louder than registered (+8 dB). Measured 2026-10-17 (offline, in-game
	-- volume chain): the old chase sat 3-11 dB under his running steps and 2-3 dB under the office bed; at 2.5 it sits
	-- level with his steps at 15 studs, 3.6 dB under them at 8 and ~19 dB over the ducked bed.
	CHASE_MUSIC_GAIN = 2.5,
	-- Intensity 2 of the chase music (motif, ticks, pulse): silent from CHASE_LAYER_FAR studs out, full within
	-- CHASE_LAYER_NEAR (2026-10-17: was 34 / 14, so it already sounds dangerous at mid distance).
	CHASE_LAYER_NEAR = 18,
	CHASE_LAYER_FAR = 50,
	-- The dread loop fades out over this (s) when the dread lets go.
	DREAD_FADE = 1.5,
	-- Accessibility default (OccupantDreadSystem.setReduceMotion): no FOV squeeze, no edge fringe, no beat flashing
	-- (the red holds steady at REDUCED_RED of its peak), still grain. Camera shake follows the cameraShake setting.
	REDUCE_MOTION = false,
	REDUCED_RED = 0.35,
	-- Each stage's look. near is scaled by proximity, aware by max(proximity, AWARE_FLOOR), the chase blends
	-- CHASE_FAR -> CHASE_NEAR by the chase layer's closeness, crew is scaled by the crew weight.
	LOOKS = table.freeze({
		near = look({
			heart = 0.5,
			dread = 1,
			vignette = 0.45,
			desaturate = 0.22,
			grain = 0.5,
			red = 0.1,
			edge = 0,
			squeeze = 0,
			duck = -5,
			muffle = -3,
		}),
		aware = look({
			heart = 0.8,
			dread = 1,
			vignette = 0.55,
			desaturate = 0.3,
			grain = 0.75,
			red = 0.28,
			edge = 0.45,
			squeeze = 0,
			duck = -8,
			muffle = -6,
		}),
		chaseFar = look({
			heart = 0.65,
			dread = 0,
			vignette = 0.5,
			desaturate = 0.3,
			grain = 0.8,
			red = 0.5,
			edge = 0.5,
			squeeze = 2,
			duck = -12,
			muffle = -6,
		}),
		chaseNear = look({
			heart = 0.8,
			dread = 0,
			vignette = 0.7,
			desaturate = 0.4,
			grain = 1,
			red = 0.7,
			edge = 0.9,
			squeeze = 7,
			duck = -15,
			muffle = -20,
		}),
		-- His slow turn or his stare (§11.2): unscaled by distance. The music ducks to near-silence (-30 dB) so the creak
		-- and your heartbeat are all there is; the dread loop sits back too.
		slowTurn = look({
			heart = 1,
			dread = 0.5,
			vignette = 0.7,
			desaturate = 0.4,
			grain = 0.9,
			red = 0.35,
			edge = 0.4,
			squeeze = 3,
			duck = -30,
			muffle = -12,
		}),
		crew = look({
			heart = 0.45,
			dread = 0.5,
			vignette = 0.3,
			desaturate = 0.15,
			grain = 0.4,
			red = 0.12,
			edge = 0.2,
			squeeze = 0,
			duck = -5,
			muffle = -4,
		}),
	}),
	-- Hiding while he is near (near, aware or chase): the heart at least HIDDEN_HEART, the world muffled to at least
	-- HIDDEN_MUFFLE and ducked to at least HIDDEN_DUCK (dB), the vignette HIDDEN_VIGNETTE stronger.
	HIDDEN_HEART = 1,
	HIDDEN_MUFFLE = -22,
	HIDDEN_DUCK = -9,
	HIDDEN_VIGNETTE = 0.1,
}

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
	SLOW_TURN_SECONDS = SLOW_TURN_SECONDS,
	SLOW_WAIST_SHARE = 0.2,
	SLOW_WAIST_LEAD = 0.6,
	SLOW_SETTLE = 0.35,
	-- Meaningful movement (never a camera turn): a flat speed of STILL_SPEED studs/s or more, or a drift of
	-- STILL_DISTANCE studs (3D, so a jump counts) from where they stood.
	STILL_SPEED = 2.5,
	STILL_DISTANCE = 1.25,
	-- Moving mid-turn: his head whips the rest of the way over WHIP_SECONDS (the whip gesture) as the jerk begins.
	WHIP_SECONDS = WHIP_SECONDS,
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
	-- The catch: camera on his face ~1 s (the jumpscare), then the launch; ~8 s spectating (Death's respawn delay).
	SNAP_SECONDS = 1,
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
	CATCH_TINT = Color3.fromRGB(255, 120, 120),
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
	CHASE_MUSIC_FADE = 1.5,
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
	DREAD = table.freeze(DREAD),
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
	-- The catch scare's grin over his face (spec §4 "stretched-grin face"; kid-safe cartoon): its billboard,
	-- size in studs, how wide the mouth stretches, teeth, colours (used while the grin image is pending).
	GRIN_NAME = "OccupantGrin",
	GRIN_SIZE = 3.2,
	GRIN_STRETCH = 0.92,
	GRIN_TEETH = 7,
	GRIN_WHITE = Color3.fromRGB(250, 250, 240),
	GRIN_INK = Color3.fromRGB(15, 10, 10),
})
