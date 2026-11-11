--[[
	The Supply Counter clerk's two generic clips (owner 11-11, "Stamp & Stack"), authored as KeyframeSequences on the
	shared employee kit rig (R15 joint names; the kit rig rests in a T-pose, arms out along X). They use no ears and no
	per-character parts, so every employee can play them (character-agnostic rule).

	- ClerkStamp (2.4 s, looped): left paw resting on the counter, the right lifts a rubber stamp, slams it down (a
	  forward lean and a short hold on the hit), lifts, then the left paw slides the stamped parcel aside.
	- ClerkGreet (1.8 s): a lean in over the counter with a head tilt and a little wave, back to the stamp's first pose.

	Joint turns are degrees about X, Y, Z (CFrame.Angles order) over the rest pose, the same convention as
	EmployeePoseRegistry: X pitches (+ tips the top back), Y yaws (+ swings the right arm forward), Z rolls (+ raises the
	right arm). The left side mirrors the right: (x, -y, -z).

	Run in the Studio command bar (Edit). It writes ReplicatedStorage.ClaudeClerkAnims (ClerkStamp, ClerkGreet) for a
	local preview (KeyframeSequenceProvider:RegisterKeyframeSequence in Play) or for the upload. Delete the folder after.
]]

local function turn(d)
	return CFrame.Angles(math.rad(d[1]), math.rad(d[2]), math.rad(d[3]))
end
local function mirror(d)
	return { d[1], -d[2], -d[3] }
end

-- The joint tree: part name -> its parent part (the Pose hierarchy follows it).
local PARENT = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperLeg = "LowerTorso",
	LeftUpperLeg = "LowerTorso",
}
-- The joint each pose turns (named for the part it moves).
local JOINT_PART = {
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
}

-- The left paw resting on the counter, the right arm's stamp heights.
local LEFT_REST = { shoulder = mirror({ 0, 52, -62 }), elbow = mirror({ 0, 38, 0 }) }
local STAMP = {
	[0] = {
		Waist = { 4, 0, 0 },
		Neck = { -10, 0, 0 },
		RightShoulder = { 0, 55, -25 },
		RightElbow = { 0, 0, 70 },
		LeftShoulder = LEFT_REST.shoulder,
		LeftElbow = LEFT_REST.elbow,
	},
	[0.35] = {
		Waist = { -6, 0, 0 },
		Neck = { -16, 0, 0 },
		RightShoulder = { 0, 62, -55 },
		RightElbow = { 0, 0, 25 },
		LeftShoulder = LEFT_REST.shoulder,
		LeftElbow = LEFT_REST.elbow,
	},
	[0.42] = {
		Waist = { -10, 0, 0 },
		Neck = { -17, 0, 0 },
		RightShoulder = { 0, 64, -63 },
		RightElbow = { 0, 0, 14 },
		LeftShoulder = LEFT_REST.shoulder,
		LeftElbow = LEFT_REST.elbow,
	},
	[0.62] = {
		Waist = { -9, 0, 2 },
		Neck = { -15, 0, 0 },
		RightShoulder = { 0, 64, -62 },
		RightElbow = { 0, 0, 16 },
		LeftShoulder = LEFT_REST.shoulder,
		LeftElbow = LEFT_REST.elbow,
	},
	[1.0] = {
		Waist = { -2, 0, 0 },
		Neck = { -8, 6, 0 },
		RightShoulder = { 0, 50, -45 },
		RightElbow = { 0, 0, 40 },
		LeftShoulder = LEFT_REST.shoulder,
		LeftElbow = LEFT_REST.elbow,
	},
	[1.35] = {
		Waist = { -4, 10, 0 },
		Neck = { -6, 12, 0 },
		RightShoulder = { 0, 45, -50 },
		RightElbow = { 0, 0, 35 },
		LeftShoulder = mirror({ 0, 72, -50 }),
		LeftElbow = mirror({ 0, 10, 0 }),
	},
	[1.75] = {
		Waist = { -3, -6, 0 },
		Neck = { -8, -6, 0 },
		RightShoulder = { 0, 50, -40 },
		RightElbow = { 0, 0, 50 },
		LeftShoulder = mirror({ 0, 32, -55 }),
		LeftElbow = mirror({ 0, 30, 0 }),
	},
}
STAMP[2.4] = STAMP[0]

local GREET = {
	[0] = STAMP[0],
	[0.3] = {
		Waist = { -14, 0, 0 },
		Neck = { -4, 0, 8 },
		RightShoulder = { 0, 0, 4 },
		RightElbow = { 0, 0, 74 },
		LeftShoulder = LEFT_REST.shoulder,
		LeftElbow = LEFT_REST.elbow,
	},
}
for i, t in { 0.55, 0.8, 1.05, 1.3 } do
	GREET[t] = table.clone(GREET[0.3])
	GREET[t].RightElbow = { 0, 0, if i % 2 == 1 then 50 else 76 }
	GREET[t].Neck = { -4, 0, if i % 2 == 1 then 12 else 6 }
end
GREET[1.8] = STAMP[0]

local function build(name, frames, looped)
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = looped
	ks.Priority = Enum.AnimationPriority.Action
	local times = {}
	for t in frames do
		table.insert(times, t)
	end
	table.sort(times)
	for _, t in times do
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local poses = {}
		local function pose(part)
			if poses[part] then
				return poses[part]
			end
			local p = Instance.new("Pose")
			p.Name = part
			p.Weight = 1
			p.EasingStyle = Enum.PoseEasingStyle.Cubic
			p.EasingDirection = Enum.PoseEasingDirection.InOut
			local parent = PARENT[part]
			p.Parent = if parent then pose(parent) else kf
			poses[part] = p
			return p
		end
		pose("HumanoidRootPart")
		for joint, d in frames[t] do
			pose(JOINT_PART[joint]).CFrame = turn(d)
		end
		kf.Parent = ks
	end
	return ks
end

local RS = game:GetService("ReplicatedStorage")
local old = RS:FindFirstChild("ClaudeClerkAnims")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "ClaudeClerkAnims"
build("ClerkStamp", STAMP, true).Parent = folder
build("ClerkGreet", GREET, false).Parent = folder
folder.Parent = RS
return "built ClerkStamp, ClerkGreet"
