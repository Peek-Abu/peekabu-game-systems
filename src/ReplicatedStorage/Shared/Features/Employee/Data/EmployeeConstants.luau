--!strict
--[=[
	EmployeeConstants: names the employee contract uses on the character model, and the tuning for the expression
	rule and the ear springs.

	@class EmployeeConstants
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

local EmployeeConstants = {
	-- On the character model: which EmployeeRegistry entry it is. Stamped by the server's install
	-- (EmployeeSpawnSystem) from the registry, so the template's own attribute is informational.
	NAME_ATTRIBUTE = "EmployeeName",
	-- On the character model, written by the server: the expression to show (an EmployeeRegistry.Face).
	-- Also stamped on the FacePlate's SurfaceAppearance by the client, to know what is showing.
	FACE_ATTRIBUTE = "EmployeeFace",
	STARTER_CHARACTER_NAME = "StarterCharacter",
	FACE_PLATE = "FacePlate",
	FACE_APPEARANCE = "Face",
	FACES_FOLDER = "Faces",
	-- Under ReplicatedStorage: art-owned Accessory instances a skin can name (EmployeeSkinSystem).
	ACCESSORIES_PATH = { "Assets", "CleanupCrew", "Accessories" },
	-- On a fitted-gear Model there (EmployeeGearSystem): the name of the body part it sits on. The Model's WorldPivot
	-- is that part's frame at the template's authored size.
	GEAR_MOUNT_ATTRIBUTE = "MountPart",
	-- In the company lanyard (EmployeeGearSystem.badge): the strap part painted in the rank colour, and the ID card's
	-- SurfaceGui elements (the holder's name, their title, the rank-colour band and its text).
	LANYARD_STRAP = "LanyardStrap",
	BADGE_HOLDER = "IdCardHolder",
	BADGE_TITLE = "IdCardTitle",
	BADGE_BAND = "IdCardBand",
	BADGE_BAND_TEXT = "IdCardBandText",

	-- Expression rule (EmployeeFaceRules).
	-- An investigating / chasing / searching Manager this close (studs) worries everyone.
	WORRIED_RADIUS = 30,
	-- Seconds an employee still counts as cleaning after the vacuum stops (bridges short gaps in suction,
	-- so the face does not flicker between sweeps).
	CLEANING_LINGER = 1,
	-- Seconds between server expression passes.
	EXPRESSION_INTERVAL = 0.25,

	-- Ear springs (client cosmetic; EmployeeEarFormulas).
	EAR_JOINTS = EAR_JOINTS,
	-- Employees farther than this (studs) from the camera keep their ears at rest.
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

return EmployeeConstants
