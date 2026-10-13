--!strict
--[=[
	EmployeeRigUtils: plans the attachments a stock R15 avatar carries but an exported employee rig lacks.

	Engine and game code find a character's joints and hands through attachments, not Motor6Ds: the
	R15 `<Joint>RigAttachment` pairs (Humanoid:BuildRigFromAttachments, the carry IK's arm reach) and the
	`RightGripAttachment` a Tool's handle is welded to. An employee exported with only Motor6Ds gets them
	generated from its joints instead, so the art never has to author them:

	- Rig attachments: one `<Joint>RigAttachment` on each side of every Motor6D, at its C0 (in Part0) and
	  C1 (in Part1), exactly where the joint pivots. That is the R15 naming rule, so rebuilding the rig from
	  the attachments reproduces the same joints (custom joints such as the ears included).
	- Grip attachments: the stock R15 grip sits at the end of the hand, down the arm, rotated -90 degrees
	  about X. "Down the arm" is read from the wrist instead of assumed to be -Y: the wrist pivot (the
	  Motor6D's C1, in hand space) sits at the arm end of the hand, so the arm runs from it through the hand's
	  centre. A T-posed employee's right arm runs along +X, and its grip turns with it, so a Tool sits in the
	  hand the same way it would on an arms-down rig once animation retargeting brings the arm down.

	Pure: plans from joint descriptions, never touches Instances.

	@class EmployeeRigUtils
]=]

export type Joint = {
	name: string,
	part0: string,
	part1: string,
	c0: CFrame,
	c1: CFrame,
}

export type Placement = {
	part: string,
	name: string,
	cframe: CFrame,
}

export type Side = "Left" | "Right"

local STOCK_DOWN = Vector3.new(0, -1, 0)
-- The stock R15 grip frame relative to "the hand, arms down".
local STOCK_GRIP_TURN = CFrame.Angles(-math.pi / 2, 0, 0)

local EmployeeRigUtils = {}

function EmployeeRigUtils.rigAttachments(joints: { Joint }): { Placement }
	local placements: { Placement } = {}
	local seen: { [string]: true } = {}
	local function add(part: string, name: string, cframe: CFrame)
		local key = part .. "\0" .. name
		if seen[key] then
			return
		end
		seen[key] = true
		table.insert(placements, { part = part, name = name, cframe = cframe })
	end
	for _, joint in joints do
		local name = joint.name .. "RigAttachment"
		add(joint.part0, name, joint.c0)
		add(joint.part1, name, joint.c1)
	end
	return placements
end

-- The hand-space axis the arm runs down: from the wrist pivot through the hand's centre, snapped to
-- the hand's dominant axis.
local function armAxis(wristC1: CFrame): Vector3
	local away = -wristC1.Position
	local ax, ay, az = math.abs(away.X), math.abs(away.Y), math.abs(away.Z)
	if ax < 1e-6 and ay < 1e-6 and az < 1e-6 then
		return STOCK_DOWN
	elseif ax >= ay and ax >= az then
		return Vector3.new(math.sign(away.X), 0, 0)
	elseif ay >= az then
		return Vector3.new(0, math.sign(away.Y), 0)
	end
	return Vector3.new(0, 0, math.sign(away.Z))
end

-- The rotation taking the stock "down the arm" (-Y) onto `axis` (a unit axis vector).
local function turnOnto(axis: Vector3): CFrame
	local dot = STOCK_DOWN:Dot(axis)
	if dot > 0.999 then
		return CFrame.identity
	elseif dot < -0.999 then
		return CFrame.Angles(0, 0, math.pi)
	end
	return CFrame.fromAxisAngle(STOCK_DOWN:Cross(axis).Unit, math.acos(dot))
end

function EmployeeRigUtils.gripAttachment(side: Side, handSize: Vector3, wristC1: CFrame): Placement
	local axis = armAxis(wristC1)
	local extent = math.abs(handSize:Dot(axis)) / 2
	return {
		part = side .. "Hand",
		name = side .. "GripAttachment",
		cframe = CFrame.new(axis * extent) * turnOnto(axis) * STOCK_GRIP_TURN,
	}
end

return EmployeeRigUtils
