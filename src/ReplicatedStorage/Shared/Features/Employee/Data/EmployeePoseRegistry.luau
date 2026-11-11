--!strict
--[=[
	EmployeePoseRegistry: how each employee stands in a UI portrait (CharacterPortrait), as data.

	A pose is a set of joint turns (Motor6D name -> degrees about X, Y, Z, applied as the joint's Transform over the
	rig's REST pose) plus the face it wears. Every employee is built on the shared kit rig (Pippa's), so they all share
	one set (`KIT_POSES`): an employee in EmployeeRegistry poses from it, and a new employee needs no entry here.
	The kit rig's rest is a T-pose (arms straight out along X, facing -Z), so every
	pose of hers lowers the arms, and her arms are short next to her head: an arm raised higher than level hides
	behind it, so raised paws come from a level upper arm and a bent elbow. A stock R15 avatar rests arms-down and
	has no set here (it is shown at rest). The axes, in the joint's parent space at rest: X pitches (+ tips the top back), Y yaws (+ swings the right arm
	forward), Z rolls (+ raises the right arm). The left side mirrors the right (`mirror`).

	Which pose a portrait uses depends on where it is shown (`PortraitContext`) and, per context, on the player's
	Clearance Level (`byLevel`: the highest listed level at or under theirs wins, so a new rank inherits the one below)
	or on the shift's grade (`byGrade`, the results' letter). EmployeePoseRules makes the choice.

	Adding a pose is one entry in `poses`; using it somewhere is one name in `contexts`. No uploads: the poses are
	applied once when the portrait is built (EmployeePortraitSystem), never animated.

	@class EmployeePoseRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

-- Where a portrait is shown: the hub's profile card, a crew roster or truck seat, the rehire notice, the results'
-- featured award; the training coach, one per kind of line (go this way, careful, cheer, shh, hide); the training
-- finish screen's victory.
export type PortraitContext =
	"profile"
	| "crew"
	| "caught"
	| "award"
	| "coachPoint"
	| "coachWarn"
	| "coachCheer"
	| "coachShh"
	| "coachHide"
	| "victory"

export type PoseDef = {
	name: string,
	-- The face it wears; nil keeps whatever the character shows.
	face: EmployeeRegistry.Face?,
	-- A portrait-only face by its name in the model's Faces folder (a reveal face, a coach face), worn instead of
	-- `face` when the employee has it; `face` is the fallback for one that does not.
	look: string?,
	-- Motor6D name -> turn in degrees (X, Y, Z) over the rest pose. Joints not named stay at rest.
	joints: { [string]: Vector3 },
}

export type ContextPoses = {
	-- The pose when nothing below picks one.
	pose: string,
	-- Clearance Level -> pose (the highest level at or under the player's wins).
	byLevel: { [number]: string }?,
	-- The results' grade letter ("A", "B", "C") -> pose.
	byGrade: { [string]: string }?,
}

export type PortraitSet = {
	poses: { [string]: PoseDef },
	contexts: { [PortraitContext]: ContextPoses },
}

local CONTEXTS: { PortraitContext } = {
	"profile",
	"crew",
	"caught",
	"award",
	"coachPoint",
	"coachWarn",
	"coachCheer",
	"coachShh",
	"coachHide",
	"victory",
}

-- The right side's turn, mirrored onto the left (Y and Z flip; X, the pitch, is shared).
local function mirror(right: Vector3): Vector3
	return Vector3.new(right.X, -right.Y, -right.Z)
end

-- Both arms from the right arm's shoulder and elbow turns.
local function arms(shoulder: Vector3, elbow: Vector3, joints: { [string]: Vector3 }): { [string]: Vector3 }
	joints.RightShoulder = shoulder
	joints.RightElbow = elbow
	joints.LeftShoulder = mirror(shoulder)
	joints.LeftElbow = mirror(elbow)
	return joints
end

local function pose(name: string, face: EmployeeRegistry.Face?, joints: { [string]: Vector3 }, look: string?): PoseDef
	local def: PoseDef = { name = name, face = face, joints = table.freeze(joints), look = look }
	return table.freeze(def)
end

-- Arms relaxed at the sides (from the T-pose: down 72 degrees, a little forward, elbows soft).
local SIDE_SHOULDER = Vector3.new(0, 10, -72)
local SIDE_ELBOW = Vector3.new(0, 12, 0)

local KIT_POSES: { [string]: PoseDef } = {
	-- Arms at her sides, content: the roster's default.
	stand = pose("stand", "Content", arms(SIDE_SHOULDER, SIDE_ELBOW, {})),
	-- The right upper arm out level and the paw up beside her head (higher, the huge head hides it), the left at
	-- her side, a happy head tilt: the hub's default.
	wave = pose("wave", "Happy", {
		RightShoulder = Vector3.new(0, 0, 4),
		RightElbow = Vector3.new(0, 0, 74),
		LeftShoulder = mirror(SIDE_SHOULDER),
		LeftElbow = mirror(SIDE_ELBOW),
		Neck = Vector3.new(0, 0, -7),
	}),
	-- New hire: paws together in front, head a little down.
	shy = pose(
		"shy",
		"Content",
		arms(Vector3.new(0, 34, -68), Vector3.new(0, 42, 0), {
			Neck = Vector3.new(-8, 0, 0),
		})
	),
	-- Senior: paws on hips, chest out.
	proud = pose(
		"proud",
		"Happy",
		arms(Vector3.new(0, -20, -45), Vector3.new(0, -30, -95), {
			Waist = Vector3.new(4, 0, 0),
			Neck = Vector3.new(5, 0, 0),
		})
	),
	-- Both paws up and out beside her head: the results' top grade.
	cheer = pose(
		"cheer",
		"Happy",
		arms(Vector3.new(0, 0, 25), Vector3.new(0, 0, 30), {
			Neck = Vector3.new(6, 0, 0),
		})
	),
	-- Shoulders dropped, head down: a missed contract.
	slump = pose(
		"slump",
		"Worried",
		arms(Vector3.new(0, 4, -80), Vector3.new(0, 6, 0), {
			Waist = Vector3.new(-6, 0, 0),
			Neck = Vector3.new(-16, 0, 0),
		})
	),
	-- Paws pulled up under her chin, leaning back: caught.
	scared = pose(
		"scared",
		"Worried",
		arms(Vector3.new(0, 60, -10), Vector3.new(0, 0, 110), {
			Waist = Vector3.new(6, 0, 0),
			Neck = Vector3.new(-6, 0, 0),
		})
	),
	-- The coach's poses (training v3, seen from the front, belly and up; checked on the rig from the coach camera for
	-- clipping: her muzzle sticks out past her short arms, so no paw goes near her mouth). Go this way: the left arm
	-- (screen right) points out and a little up, the right paw on her hip, leaning and twisting into it, head tipped.
	point = pose("point", "Happy", {
		LeftShoulder = mirror(Vector3.new(0, 16, 18)),
		LeftElbow = mirror(Vector3.new(0, 0, 0)),
		RightShoulder = Vector3.new(0, -20, -45),
		RightElbow = Vector3.new(0, -30, -95),
		Waist = Vector3.new(-3, -12, 8),
		Neck = Vector3.new(5, 10, -12),
	}),
	-- Careful!: a worried "whoa": both paws up in front at chest height (a paw near her head would sink into her
	-- cheek: her head is wider than her shoulders), leaning back, head tipped away.
	warn = pose("warn", "Worried", {
		RightShoulder = Vector3.new(0, 56, -40),
		RightElbow = Vector3.new(0, 0, 64),
		RightWrist = Vector3.new(40, 0, 0),
		LeftShoulder = mirror(Vector3.new(0, 48, -46)),
		LeftElbow = mirror(Vector3.new(0, 0, 58)),
		LeftWrist = mirror(Vector3.new(35, 0, 0)),
		Waist = Vector3.new(12, 8, -6),
		Neck = Vector3.new(-6, -10, 14),
	}),
	-- Shh, sneak: ears pinned flat back, hunched on a diagonal, tiptoe paws drooping in front (not at her mouth: it
	-- would clip), head cocked the other way; her sly "Shh" face (Content where an employee has none).
	shh = pose("shh", "Content", {
		RightShoulder = Vector3.new(0, 50, -8),
		RightElbow = Vector3.new(0, 0, 70),
		RightWrist = Vector3.new(-75, 0, 0),
		LeftShoulder = mirror(Vector3.new(0, 40, -22)),
		LeftElbow = mirror(Vector3.new(0, 0, 60)),
		LeftWrist = mirror(Vector3.new(-70, 0, 0)),
		Waist = Vector3.new(-16, 14, 14),
		Neck = Vector3.new(6, -12, -16),
		RightEarBase = Vector3.new(55, 0, -10),
		LeftEarBase = Vector3.new(60, 0, 12),
	}, "Shh"),
	-- Hide!: a cower that fits every employee (owner 11-10: the ears folded over her eyes read wrong, and an ear
	-- trick depends on each employee's ears): curled forward, head ducked, both arms hugged in tight at the chest, ears
	-- pinned flat back further than the sneak's (an employee with none just cowers). Her Scared face where she has
	-- one, Worried otherwise.
	hide = pose("hide", "Worried", {
		RightShoulder = Vector3.new(0, 64, -40),
		RightElbow = Vector3.new(0, 0, 100),
		LeftShoulder = mirror(Vector3.new(0, 58, -46)),
		LeftElbow = mirror(Vector3.new(0, 0, 92)),
		Waist = Vector3.new(14, 0, 4),
		Neck = Vector3.new(12, -8, 6),
		RightEarBase = Vector3.new(72, 0, -22),
		LeftEarBase = Vector3.new(76, 0, 24),
	}, "Scared"),
	-- You did it!: both paws up beside her head (the right higher, out clear of her face), leaning back, head tipped.
	coachCheer = pose("coachCheer", "Happy", {
		RightShoulder = Vector3.new(0, -30, 12),
		RightElbow = Vector3.new(0, 0, 20),
		LeftShoulder = mirror(Vector3.new(0, -14, 22)),
		LeftElbow = mirror(Vector3.new(0, 0, 55)),
		Waist = Vector3.new(10, 4, 6),
		Neck = Vector3.new(8, -6, -10),
	}, "RevealExcited"),
	-- The training finish: the right fist up high, the left arm out, leaning back, proud.
	victory = pose("victory", "Happy", {
		RightShoulder = Vector3.new(0, -30, 18),
		RightElbow = Vector3.new(0, 0, 18),
		LeftShoulder = mirror(Vector3.new(0, 20, -22)),
		LeftElbow = mirror(Vector3.new(0, 30, 0)),
		Waist = Vector3.new(6, 0, 0),
		Neck = Vector3.new(6, 0, -6),
	}),
}

local KIT_SET: PortraitSet = {
	poses = KIT_POSES,
	contexts = {
		profile = { pose = "wave", byLevel = { [1] = "shy", [2] = "wave", [3] = "proud" } },
		crew = { pose = "stand" },
		caught = { pose = "scared" },
		award = { pose = "cheer", byGrade = { A = "cheer", B = "wave", C = "slump" } },
		coachPoint = { pose = "point" },
		coachWarn = { pose = "warn" },
		coachCheer = { pose = "coachCheer" },
		coachShh = { pose = "shh" },
		coachHide = { pose = "hide" },
		victory = { pose = "victory" },
	},
}

local EmployeePoseRegistry = {
	CONTEXTS = CONTEXTS,
	-- Top-level children of a character a portrait leaves out: equipment, not the look (Tools always go too).
	STRIP = table.freeze({ "VacuumBackpack" }),
	mirror = mirror,
}

-- The employee's set: the kit's for every registered employee (without one, a stock avatar stays at rest).
function EmployeePoseRegistry.get(employee: string): PortraitSet?
	return if EmployeeRegistry.get(employee) ~= nil then KIT_SET else nil
end

-- The employees that have a set (every registered one), sorted.
function EmployeePoseRegistry.names(): { string }
	return EmployeeRegistry.names()
end

return EmployeePoseRegistry
