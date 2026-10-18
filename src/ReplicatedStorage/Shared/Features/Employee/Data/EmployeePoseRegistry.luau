--!strict
--[=[
	EmployeePoseRegistry: how each employee stands in a UI portrait (CharacterPortrait), as data.

	A pose is a set of joint turns (Motor6D name -> degrees about X, Y, Z, applied as the joint's Transform over the
	rig's REST pose) plus the face it wears. Pippa's rest is a T-pose (arms straight out along X, facing -Z), so every
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
-- featured award.
export type PortraitContext = "profile" | "crew" | "caught" | "award"

export type PoseDef = {
	name: string,
	-- The face it wears; nil keeps whatever the character shows.
	face: EmployeeRegistry.Face?,
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

local CONTEXTS: { PortraitContext } = { "profile", "crew", "caught", "award" }

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

local function pose(name: string, face: EmployeeRegistry.Face?, joints: { [string]: Vector3 }): PoseDef
	local def: PoseDef = { name = name, face = face, joints = table.freeze(joints) }
	return table.freeze(def)
end

-- Arms relaxed at the sides (from the T-pose: down 72 degrees, a little forward, elbows soft).
local SIDE_SHOULDER = Vector3.new(0, 10, -72)
local SIDE_ELBOW = Vector3.new(0, 12, 0)

local PIPPA_POSES: { [string]: PoseDef } = {
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
}

local PORTRAITS: { [string]: PortraitSet } = {
	Pippa = {
		poses = PIPPA_POSES,
		contexts = {
			profile = { pose = "wave", byLevel = { [1] = "shy", [2] = "wave", [3] = "proud" } },
			crew = { pose = "stand" },
			caught = { pose = "scared" },
			award = { pose = "cheer", byGrade = { A = "cheer", B = "wave", C = "slump" } },
		},
	},
}

local EmployeePoseRegistry = {
	CONTEXTS = CONTEXTS,
	-- Top-level children of a character a portrait leaves out: equipment, not the look (Tools always go too).
	STRIP = table.freeze({ "VacuumBackpack" }),
	mirror = mirror,
}

function EmployeePoseRegistry.get(employee: string): PortraitSet?
	return PORTRAITS[employee]
end

function EmployeePoseRegistry.names(): { string }
	local names = {}
	for name in PORTRAITS do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return EmployeePoseRegistry
