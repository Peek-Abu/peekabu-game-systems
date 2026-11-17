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

-- Where a portrait is shown: the hub's profile card, a crew roster or truck seat, the rank chart's step (`ladder`),
-- the rehire notice, the results' featured award; the training coach, one per kind of line (go this way, careful,
-- cheer, shh, hide); the training finish screen's victory; `idle`, a still preview with no place of its own (the Shop,
-- Inventory, the pick screen, the Locker and the deals: the employee held in its own idle).
export type PortraitContext =
	"idle"
	| "profile"
	| "crew"
	| "ladder"
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
	"idle",
	"profile",
	"crew",
	"ladder",
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

-- A new pose at every rank (p075, owner yes 2026-11-14): the hub's profile card, the crew pictures and the rank
-- chart all show the player's employee in their rank's pose, so ranking up visibly changes how you stand. One table,
-- shared, so the three never disagree; a rank added later inherits the pose below it (EmployeePoseRules).
-- A still preview's idle pose for an employee with none of its own (`IDLE_POSES`): the shared stand.
KIT_POSES.idle = table.freeze({ name = "idle", face = KIT_POSES.stand.face, joints = KIT_POSES.stand.joints })

--[=[
	Each employee's own idle, held still (owner 2026-11-15: a still preview shows the employee in its default idle, not
	the shared stand). Joint turns over the kit rig's rest, read from the FIRST keyframe of the employee's idle loop
	(EmployeeRegistry locomotion.idle) with KeyframeSequenceProvider in Studio: Pose.CFrame:ToEulerAnglesXYZ() in
	degrees, rounded to 0.1 (the root's small shift is left out: a still pose turns joints only). The live
	preview starts its idle at that same frame, so swapping the still for the moving model never jumps. A new employee
	(Morel, Bigsby) adds its entry here; without one it stands in the shared stand. Stored, never sampled at runtime
	(perf 2026-11-15: no clip loading on a preview).
]=]
local IDLE_POSES: { [string]: { [string]: Vector3 } } = {
	-- Pippa's idle: arms relaxed low, a soft knee bend (pippaidle, read 2026-11-15).
	Pippa = {
		Neck = Vector3.new(4.2, -5, 3.6),
		Waist = Vector3.new(-1.5, -1.1, -0.2),
		Root = Vector3.new(-1.5, -0.8, 0),
		RightShoulder = Vector3.new(-22.4, -11.1, -57.3),
		RightElbow = Vector3.new(-30.9, 78.3, 30.3),
		RightWrist = Vector3.new(0.1, -3.7, 2),
		LeftShoulder = Vector3.new(-21.4, 13.5, 58.6),
		LeftElbow = Vector3.new(-33.8, -79.3, -33.3),
		LeftWrist = Vector3.new(0.1, 3.7, -2),
		RightHip = Vector3.new(26.5, 0.7, -0.3),
		RightKnee = Vector3.new(-50.5, 0, 0),
		RightAnkle = Vector3.new(25.5, 0, 0),
		LeftHip = Vector3.new(25.9, 0.7, -0.3),
		LeftKnee = Vector3.new(-50.5, 0, 0),
		LeftAnkle = Vector3.new(26.1, 0, 0),
	},
	-- Cappy's idle: slouched, hands in his hoodie pocket (cappyidle, read 2026-11-15).
	Cappy = {
		Neck = Vector3.new(10.1, -4.6, 8.3),
		Waist = Vector3.new(-6.1, -0.6, -3.7),
		Root = Vector3.new(-4, -0.5, 3),
		RightShoulder = Vector3.new(-23.2, 39.7, -49.2),
		RightElbow = Vector3.new(-93.4, 29.8, 96.8),
		RightWrist = Vector3.new(0, 0, 2),
		LeftShoulder = Vector3.new(-22.6, -38.2, 49.5),
		LeftElbow = Vector3.new(-95.5, -29.5, -101.1),
		LeftWrist = Vector3.new(0, 0, -2),
		RightHip = Vector3.new(26.1, -1.6, -8.4),
		RightKnee = Vector3.new(-42.6, 0, 0),
		RightAnkle = Vector3.new(20.5, -1.4, 5.4),
		LeftHip = Vector3.new(31.1, -2.4, -8.5),
		LeftKnee = Vector3.new(-53.4, 0, 0),
		LeftAnkle = Vector3.new(26.3, -1.4, 5.7),
	},
	-- Prickles' idle: arms crossed (pricklesidle, read 2026-11-15). The arms are the A3 idle's (owner 11-16: lower and
	-- looser, out of his chest and head, the left paw resting on the right arm; read from the A3 clip's first keyframe
	-- the same way); his body, legs and head are unchanged.
	Prickles = {
		Neck = Vector3.new(-2.7, 0, 1.5),
		Waist = Vector3.new(1.9, -0.1, -0.3),
		Root = Vector3.new(0.1, 0.1, -0.1),
		RightShoulder = Vector3.new(-10.9, 81.3, -26.9),
		RightElbow = Vector3.new(-60.2, 38.4, 41.6),
		RightWrist = Vector3.new(-23.7, 9.8, -17.1),
		LeftShoulder = Vector3.new(56, -66, 71.3),
		LeftElbow = Vector3.new(-35, -57.4, -31),
		LeftWrist = Vector3.new(-23.9, -7.1, 26.7),
		RightHip = Vector3.new(12.5, 0.8, 3.4),
		RightKnee = Vector3.new(-22.5, 0, 0),
		RightAnkle = Vector3.new(9, -14, -3.5),
		LeftHip = Vector3.new(10.2, -0.3, -1.6),
		LeftKnee = Vector3.new(-22.8, 0, 0),
		LeftAnkle = Vector3.new(12.3, 9.9, 1.7),
	},
}
for name, joints in IDLE_POSES do
	IDLE_POSES[name] = table.freeze(joints)
end
table.freeze(IDLE_POSES)

local RANK_POSES: { [number]: string } = table.freeze({
	[1] = "shy",
	[2] = "wave",
	[3] = "proud",
	[4] = "point",
	[5] = "coachCheer",
	[6] = "cheer",
	[7] = "victory",
})

local KIT_SET: PortraitSet = {
	poses = KIT_POSES,
	contexts = {
		idle = { pose = "idle" },
		profile = { pose = "wave", byLevel = RANK_POSES },
		crew = { pose = "stand", byLevel = RANK_POSES },
		ladder = { pose = "proud", byLevel = RANK_POSES },
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
	RANK_POSES = RANK_POSES,
	IDLE_POSES = IDLE_POSES,
	-- Top-level children of a character a portrait leaves out: equipment, not the look (Tools always go too).
	STRIP = table.freeze({ "VacuumBackpack" }),
	mirror = mirror,
}

-- Each employee's set, made once: the kit's poses, each wearing the employee's own face where its personality names
-- one (EmployeeRegistry `poseFaces`, worn when the model has it; the pose's face otherwise), and its own idle pose
-- (`IDLE_POSES`) where it has one.
local SETS: { [string]: PortraitSet } = {}

-- The employee's set: the kit's for every registered employee (without one, a stock avatar stays at rest).
function EmployeePoseRegistry.get(employee: string): PortraitSet?
	local def = EmployeeRegistry.get(employee)
	if def == nil then
		return nil
	end
	local own = def.poseFaces
	local idle = IDLE_POSES[employee]
	if own == nil and idle == nil then
		return KIT_SET
	end
	local made = SETS[employee]
	if made == nil then
		local poses: { [string]: PoseDef } = {}
		for name, kit in KIT_POSES do
			local face = if own ~= nil then own[name] else nil
			poses[name] = if face ~= nil
				then table.freeze({ name = kit.name, face = kit.face, joints = kit.joints, look = face })
				else kit
		end
		if idle ~= nil then
			-- No face: the still keeps the face the employee's model wears, as its idle does.
			poses.idle = table.freeze({ name = "idle", joints = idle })
		end
		made = table.freeze({ poses = table.freeze(poses), contexts = KIT_SET.contexts })
		SETS[employee] = made
	end
	return made
end

-- The employees that have a set (every registered one), sorted.
function EmployeePoseRegistry.names(): { string }
	return EmployeeRegistry.names()
end

return EmployeePoseRegistry
