--!strict
--[=[
	OccupantGestureConstants: the procedural gestures laid over an occupant's animation (the swivels, the peek, the
	sit-in, the perch and its drop), and the beats they share with the brain's timing (the slow turn, the whip, the
	drop's fall / squash / rise). Split out of OccupantConstants, which re-exports every value and type unchanged
	(OccupantConstants.GESTURES, .GestureKey, .DROP_SECONDS, ...): read them from there. Static data (spec-exempt).

	@class OccupantGestureConstants
]=]

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

-- A perch kind's perch and drop (B4, owner 11-14: "bramble should get a perch and drop"), on the standard R15 joint
-- names only, so any R15 rig takes them (a joint the rig lacks is skipped). Hip X > 0 swings the thigh forward, knee
-- X < 0 folds the shin back, and the ankle undoes both so the feet stay flat (hip + knee + ankle = 0). Every pose
-- here is in place: it never moves the body across the floor (the server moves the root, on checked paths).
-- Perched: the flattest owl crouch on a prop's top (owner play-check 11-14: on top, never through the ceiling), body
-- hunched low over the edge, legs tucked under it, face tipped about 65 degrees down at the crew, wings held close.
-- The server sets its lowest point on the prop's visible top (OccupantSeatSystem.perch, measured with
-- OccupantGestureFormulas.posedBox on the rig's own parts); Bramble's 0.9 scale makes it fit a 7-stud locker under a
-- 13-stud ceiling.
local PERCH_CROUCH: { [string]: Vector3 } = table.freeze({
	-- -75 (measured 11-14 on Bramble at 0.9: 5.44 studs tall, under the 5.7 a 7-stud locker leaves; -70 was 5.85).
	Waist = Vector3.new(-75, 0, 0),
	Neck = Vector3.new(10, 0, 8),
	LeftHip = Vector3.new(150, 0, 0),
	RightHip = Vector3.new(150, 0, 0),
	LeftKnee = Vector3.new(-150, 0, 0),
	RightKnee = Vector3.new(-150, 0, 0),
	LeftAnkle = Vector3.new(0, 0, 0),
	RightAnkle = Vector3.new(0, 0, 0),
	LeftShoulder = Vector3.new(0, 0, -10),
	RightShoulder = Vector3.new(0, 0, 10),
})
-- The drop: off the top with the legs tucked and the wings spread high, then a squash on landing. (Bramble's bind pose
-- already holds its wings out, so the wing lifts stay small: at 75 they crossed behind its head.)
local DROP_LEAP: { [string]: Vector3 } = table.freeze({
	Waist = Vector3.new(-12, 0, 0),
	Neck = Vector3.new(12, 0, 0),
	LeftHip = Vector3.new(45, 0, 0),
	RightHip = Vector3.new(45, 0, 0),
	LeftKnee = Vector3.new(-75, 0, 0),
	RightKnee = Vector3.new(-75, 0, 0),
	LeftAnkle = Vector3.new(30, 0, 0),
	RightAnkle = Vector3.new(30, 0, 0),
	LeftShoulder = Vector3.new(0, 0, -40),
	RightShoulder = Vector3.new(0, 0, 40),
})
local DROP_SQUASH: { [string]: Vector3 } = table.freeze({
	Waist = Vector3.new(-34, 0, 0),
	Neck = Vector3.new(30, 0, 0),
	LeftHip = Vector3.new(70, 0, 0),
	RightHip = Vector3.new(70, 0, 0),
	LeftKnee = Vector3.new(-110, 0, 0),
	RightKnee = Vector3.new(-110, 0, 0),
	LeftAnkle = Vector3.new(40, 0, 0),
	RightAnkle = Vector3.new(40, 0, 0),
	LeftShoulder = Vector3.new(0, 0, -25),
	RightShoulder = Vector3.new(0, 0, 25),
})
-- The drop's beats (seconds): the fall from the top to the floor point (with a DROP_HOP studs hop up off it), the
-- squash held on landing, and the rise back to standing. DROP_SECONDS is all three: the drop gesture's length.
local DROP_FALL_SECONDS = 0.42
local DROP_SQUASH_SECONDS = 0.18
local DROP_RISE_SECONDS = 0.3
local DROP_SECONDS = DROP_FALL_SECONDS + DROP_SQUASH_SECONDS + DROP_RISE_SECONDS
local DROP_LANDED = DROP_FALL_SECONDS / DROP_SECONDS
local DROP_SQUASHED = (DROP_FALL_SECONDS + 0.06) / DROP_SECONDS
local DROP_RISING = (DROP_FALL_SECONDS + DROP_SQUASH_SECONDS) / DROP_SECONDS

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
	-- A perch kind on a perch (mode "perch"): it settles into the crouch.
	perch = { seconds = 0.3, joints = PERCH_CROUCH },
	-- Its drop (DROP_SECONDS from when it left the perch): from the crouch, the leap (tucked, wings high) through the
	-- fall, the squash as it lands, held, then the rise to standing. The server moves the root along the same beats.
	drop = {
		seconds = DROP_SECONDS,
		joints = REST,
		keys = {
			key(0, 0, PERCH_CROUCH),
			key(0.12, 0, DROP_LEAP),
			key(DROP_LANDED, 0, DROP_LEAP),
			key(DROP_SQUASHED, 0, DROP_SQUASH),
			key(DROP_RISING, 0, DROP_SQUASH),
			key(1, 0, REST),
		},
	},
}

return table.freeze({
	GESTURES = table.freeze(GESTURES),
	-- His clock-head hands (OccupantClockFormulas): how fast the minute hand winds while he hunts and on the catch
	-- (turns per second; the hour hand goes one twelfth as fast), how fast it spins up and winds down (turns per
	-- second, per second), and the slow speed it settles back onto 12 at.
	CLOCK = table.freeze({
		huntTurns = 1.25,
		catchTurns = 3,
		spinUp = 6,
		spinDown = 3,
		settleTurns = 0.6,
	}),
	SLOW_TURN_SECONDS = SLOW_TURN_SECONDS,
	WHIP_SECONDS = WHIP_SECONDS,
	DROP_FALL_SECONDS = DROP_FALL_SECONDS,
	DROP_SQUASH_SECONDS = DROP_SQUASH_SECONDS,
	DROP_RISE_SECONDS = DROP_RISE_SECONDS,
	DROP_SECONDS = DROP_SECONDS,
})
