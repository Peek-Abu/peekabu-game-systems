--[[
	The Supply Counter clerk's two generic clips (owner 11-11, "Stamp & Stack"; v2: bigger, so they read from hub
	distance), authored as KeyframeSequences on the shared employee kit rig (R15 joint names; the kit rig rests in a
	T-pose, arms out along X). No ears and no per-character parts, so every employee can play them.

	- ClerkStamp (2.6 s, looped): TELEGRAPH - the stamp winds up high beside the head (out to the side, so the big heads never hide it), the body rising onto
	  its toes and leaning back; STRIKE - three frames down, the torso folding forward; IMPACT - a squash (the root
	  drops, knees bend, head ducks) held for a beat, with the marker "Thunk" (the code hops the parcel and plays the
	  thunk there); recover with an overshoot; then the left paw sweeps the parcel aside with the whole torso turning.
	- ClerkGreet (2.2 s): a big lean in over the counter (waist and neck forward), a head tilt, and three wide waves
	  from the shoulder with the arm up high, then back to the stamp's first pose.

	Joint turns are degrees about X, Y, Z (CFrame.Angles order) over the rest pose (EmployeePoseRegistry's convention):
	X pitches (+ tips the top back), Y yaws (+ swings the right arm forward), Z rolls (+ raises the right arm). The
	left side mirrors the right: (x, -y, -z). `Root` is a drop/raise of the LowerTorso in studs (a squash or a hop).

	Run in the Studio command bar (Edit). It writes ReplicatedStorage.ClaudeClerkAnims (ClerkStamp, ClerkGreet) for a
	local preview (KeyframeSequenceProvider:RegisterKeyframeSequence in Play) or for the upload. Delete it after.
]]

local function turn(d)
	return CFrame.Angles(math.rad(d[1]), math.rad(d[2]), math.rad(d[3]))
end
local function mirror(d)
	return { d[1], -d[2], -d[3] }
end

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
	RightLowerLeg = "RightUpperLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
}
local JOINT_PART = {
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
}

local LEFT_REST = { shoulder = mirror({ 0, 52, -62 }), elbow = mirror({ 0, 38, 0 }) }
local function pose(t)
	t.LeftShoulder = t.LeftShoulder or LEFT_REST.shoulder
	t.LeftElbow = t.LeftElbow or LEFT_REST.elbow
	return t
end

local STAMP = {
	-- ready: stamp at chest height
	[0] = pose({ Waist = { 0, 0, 0 }, Neck = { -8, 0, 0 }, RightShoulder = { 0, 55, -20 }, RightElbow = { 0, 0, 75 } }),
	-- TELEGRAPH: wind up high and back, rise and lean back
	-- (the kit's arms are short and its heads big: a bent elbow puts the hand inside the head, so the arm stays
	-- nearly straight and the torso rolls away from it, which keeps the stamp clear of the head from the front)
	[0.55] = pose({
		Root = 0.25,
		Waist = { 14, -12, 10 },
		Neck = { 8, -10, 0 },
		RightShoulder = { 0, 5, 40 },
		RightElbow = { 0, 0, 25 },
	}),
	[0.7] = pose({
		Root = 0.3,
		Waist = { 16, -14, 16 },
		Neck = { 10, -10, 0 },
		RightShoulder = { 0, 0, 48 },
		RightElbow = { 0, 0, 10 },
	}),
	-- STRIKE: fast, folding forward
	[0.8] = pose({
		Root = 0.0,
		Waist = { -10, 4, 0 },
		Neck = { -12, 0, 0 },
		RightShoulder = { 0, 70, -20 },
		RightElbow = { 0, 0, 30 },
	}),
	-- IMPACT: squash, held; the stamp lands forward at counter height (a flat parcel, top ~1.2 studs above the feet)
	[0.86] = pose({
		Root = -0.35,
		Waist = { -24, 6, 0 },
		Neck = { -22, 0, 0 },
		RightShoulder = { 0, 80, -15 },
		RightElbow = { 0, 0, 20 },
		RightHip = { -20, 0, 0 },
		LeftHip = { -20, 0, 0 },
		RightKnee = { 30, 0, 0 },
		LeftKnee = { 30, 0, 0 },
	}),
	[1.05] = pose({
		Root = -0.3,
		Waist = { -22, 6, 0 },
		Neck = { -20, 0, 0 },
		RightShoulder = { 0, 80, -12 },
		RightElbow = { 0, 0, 22 },
		RightHip = { -16, 0, 0 },
		LeftHip = { -16, 0, 0 },
		RightKnee = { 24, 0, 0 },
		LeftKnee = { 24, 0, 0 },
	}),
	-- recover with an overshoot
	[1.3] = pose({
		Root = 0.08,
		Waist = { 6, 0, 0 },
		Neck = { 2, 8, 0 },
		RightShoulder = { 0, 50, -30 },
		RightElbow = { 0, 0, 55 },
	}),
	-- sweep the parcel aside with the left paw, the torso turning
	[1.75] = pose({
		Waist = { -8, 22, 0 },
		Neck = { -6, 22, 0 },
		RightShoulder = { 0, 45, -40 },
		RightElbow = { 0, 0, 45 },
		LeftShoulder = mirror({ 0, 80, -45 }),
		LeftElbow = mirror({ 0, 5, 0 }),
	}),
	[2.15] = pose({
		Waist = { -4, -14, 0 },
		Neck = { -6, -14, 0 },
		RightShoulder = { 0, 50, -30 },
		RightElbow = { 0, 0, 60 },
		LeftShoulder = mirror({ 0, 25, -50 }),
		LeftElbow = mirror({ 0, 30, 0 }),
	}),
}
STAMP[2.6] = STAMP[0]
local STAMP_MARKERS = { [0.86] = "Thunk" }

local GREET = {
	[0] = STAMP[0],
	-- a big lean in over the counter, head tilted, arm going up
	[0.35] = pose({
		Waist = { -28, 0, 0 },
		Neck = { -6, 0, 14 },
		RightShoulder = { 0, -20, 50 },
		RightElbow = { 0, 0, 50 },
	}),
}
-- three wide waves: the whole torso rocks side to side with the arm (the short arm alone swings too little to read
-- from hub distance), the head counter-tilting
for i, t in { 0.6, 0.85, 1.1, 1.35, 1.6 } do
	local out = i % 2 == 1
	GREET[t] = pose({
		Waist = { -14, 0, if out then 22 else 6 },
		Neck = { -6, 0, if out then -10 else 4 },
		RightShoulder = { 0, -20, if out then 52 else 40 },
		RightElbow = { 0, 0, if out then 5 else 60 },
	})
end
GREET[2.2] = STAMP[0]

local function build(name, frames, looped, markers)
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
		local function at(part)
			if poses[part] then
				return poses[part]
			end
			local p = Instance.new("Pose")
			p.Name = part
			p.Weight = 1
			p.EasingStyle = Enum.PoseEasingStyle.Cubic
			p.EasingDirection = Enum.PoseEasingDirection.InOut
			local parent = PARENT[part]
			p.Parent = if parent then at(parent) else kf
			poses[part] = p
			return p
		end
		at("HumanoidRootPart")
		for joint, d in frames[t] do
			if joint == "Root" then
				at("LowerTorso").CFrame = CFrame.new(0, d, 0)
			else
				at(JOINT_PART[joint]).CFrame = turn(d)
			end
		end
		if markers and markers[t] then
			local m = Instance.new("KeyframeMarker")
			m.Name = markers[t]
			kf:AddMarker(m)
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
build("ClerkStamp", STAMP, true, STAMP_MARKERS).Parent = folder
build("ClerkGreet", GREET, false, nil).Parent = folder
folder.Parent = RS
return "built ClerkStamp, ClerkGreet (v3)"
