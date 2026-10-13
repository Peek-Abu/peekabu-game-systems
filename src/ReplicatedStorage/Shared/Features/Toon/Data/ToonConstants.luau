--!strict
--[=[
	ToonConstants: names the toon contract uses on the character model, and the tuning for the expression
	rule and the ear springs.

	@class ToonConstants
]=]

export type EarJoint = {
	-- The Motor6D's name (Part0 = Head, Part1 = the ear; the pivot sits at the ear root).
	name: string,
	-- -1 for the left ear, 1 for the right ear: which way is "outward".
	side: number,
}

local EAR_JOINTS: { EarJoint } = {
	{ name = "LeftEarBase", side = -1 },
	{ name = "RightEarBase", side = 1 },
}

local ToonConstants = {
	-- On the character model (authored on the template, copied to every spawn).
	NAME_ATTRIBUTE = "ToonName",
	-- On the character model, written by the server: the expression to show (a ToonRegistry.Face).
	-- Also stamped on the FacePlate's SurfaceAppearance by the client, to know what is showing.
	FACE_ATTRIBUTE = "ToonFace",
	STARTER_CHARACTER_NAME = "StarterCharacter",
	FACE_PLATE = "FacePlate",
	FACE_APPEARANCE = "Face",
	FACES_FOLDER = "Faces",

	-- Expression rule (ToonFaceRules).
	-- An investigating / chasing / searching Manager this close (studs) worries everyone.
	WORRIED_RADIUS = 30,
	-- Seconds a toon stays Happy after it stops vacuuming, carrying or holding cargo (covers banking).
	HAPPY_LINGER = 3,
	-- Seconds between server expression passes.
	EXPRESSION_INTERVAL = 0.25,

	-- Ear springs (client cosmetic; ToonEarFormulas).
	EAR_JOINTS = EAR_JOINTS,
	-- Toons farther than this (studs) from the camera keep their ears at rest.
	EAR_RADIUS = 100,
	-- The ears are rigid one-piece meshes: past this the bend reads as broken.
	EAR_MAX_ANGLE = math.rad(30),
	-- Spring gains (1/s^2, 1/s): damping ratio ~0.45, a little bounce.
	EAR_STIFFNESS = 90,
	EAR_DAMPING = 8.5,
	-- Longest step the spring integrates at once, and the frame it is broken into.
	EAR_MAX_DT = 0.1,
	EAR_SUBSTEP = 1 / 120,
	-- Lean back per stud/s of forward speed (16 studs/s walk ~ 21 degrees).
	EAR_PITCH_PER_SPEED = math.rad(1.3),
	-- Outward swing per rad/s of turning.
	EAR_OUT_PER_YAW = math.rad(5),
	-- Outward swing per stud/s of sideways speed (against the motion).
	EAR_OUT_PER_LATERAL = math.rad(1.2),
	-- Outward droop per stud/s rising; inward press per stud/s falling.
	EAR_OUT_PER_RISE = math.rad(0.8),
	EAR_IN_PER_FALL = math.rad(0.3),
	-- A vertical speed change (studs/s, upward, within one step) beyond this is a landing.
	EAR_LANDING_THRESHOLD = 12,
	-- Outward spring velocity (rad/s) per stud/s of landing, and its cap.
	EAR_LANDING_KICK = 0.12,
	EAR_LANDING_KICK_MAX = 7,
	-- Idle sway: amplitude (rad) and angular rate (rad/s).
	EAR_SWAY_AMPLITUDE = math.rad(3),
	EAR_SWAY_RATE = 1.7,
}

return ToonConstants
