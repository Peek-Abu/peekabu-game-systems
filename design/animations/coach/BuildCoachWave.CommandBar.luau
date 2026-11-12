--[[
	Coach Pippa's wave, v2 (owner 11-11: "needs more enthusiasm ... the right elbow needs a lot more bend. Right now the
	wave moves the ENTIRE ARM"). A generic clip on the shared employee kit rig (R15 joint names, T-pose rest, arms out
	along X), so any employee can play it; it plays over the stock idle (Action priority) and fades out back to it.

	Beats (30 fps grid, f(n) = n/30, 2.1 s):
	- f0  arm at the side (the idle's arm), weight even.
	- f5  ANTICIPATION: a little dip and lean away, the arm cocked low (elbow bent), so the reach up has a wind-up.
	- f12 HELLO: the upper arm swings forward and out (45 deg forward, level) with the elbow bent 45 deg, so the hand
	  is up in front of the cheek: the kit's heads are ~2 studs wide and its arms ~0.7 long, so a hand raised beside
	  the head ends up inside or behind it (measured by FK on Pippa); in front of the face at chin height is where it
	  shows. The body pops up out of the dip and leans to the off side, the head tilts in.
	- f14-f48 THE WAVE: the forearm swings out and in about the elbow (elbow 25 <-> 70 deg, a 45 deg swing) with a
	  wrist flick, the hand leading. The shoulder follows 2 frames late with only a 10 deg counter-swing, so the
	  motion lives in the forearm, not the whole arm. Each "out" gets a small bounce of the hips and the torso rocks a
	  few degrees with it; the free arm swings a little the other way.
	- f52 down: the arm drops with the elbow still soft; f63 back to the side, at rest (the idle takes over).

	Joint turns are degrees about X, Y, Z (CFrame.Angles order) over the rest pose: X pitches (+ tips the top back), Y
	yaws (+ swings the right arm forward), Z rolls (+ raises the right arm; on the elbow, + bends the forearm up). The
	left side mirrors the right: (x, -y, -z). `Root` drops the LowerTorso in studs; the legs are solved for it (the
	clerk's two-bone solve, feet within 0.031 studs on every employee).

	Run in the Studio command bar (Edit). It writes ReplicatedStorage.ClaudeCoachWave (CoachWave) for the preview and
	the upload. Delete it after.
]]

local function turn(d)
	return CFrame.Angles(math.rad(d[1]), math.rad(d[2]), math.rad(d[3]))
end
local function mirror(d)
	return { d[1], -d[2], -d[3] }
end
local function f(n)
	return n / 30
end

local THIGH, SHIN = 0.31, 0.373
local HIP_SCALE = 0.93
local function legs(drop)
	if drop <= 0 then
		return 0, 0
	end
	local reach = THIGH + SHIN - drop
	local knee = math.acos(math.clamp((THIGH ^ 2 + SHIN ^ 2 - reach ^ 2) / (2 * THIGH * SHIN), -1, 1))
	local hip = math.acos(math.clamp((THIGH ^ 2 + reach ^ 2 - SHIN ^ 2) / (2 * THIGH * reach), -1, 1))
	return math.deg(hip) * HIP_SCALE, 180 - math.deg(knee)
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
	RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
}
local JOINT_PART = {
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
}
local EASE = {
	inout = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.InOut },
	["in"] = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.In },
	out = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.Out },
}

local function pose(t)
	if t.Root ~= nil then
		local hip, knee = legs(-t.Root)
		t.RightHip, t.LeftHip = { -hip, 0, 0 }, { -hip, 0, 0 }
		t.RightKnee, t.LeftKnee = { knee, 0, 0 }, { knee, 0, 0 }
		t.RightAnkle, t.LeftAnkle = { hip - knee, 0, 0 }, { hip - knee, 0, 0 }
	end
	return t
end

-- Arms down by the sides (the idle's arms), the start and the end.
local SIDE = { shoulder = { 0, 8, -72 }, elbow = { 0, 0, 12 } }
local LEFT_SIDE = { shoulder = mirror(SIDE.shoulder), elbow = mirror(SIDE.elbow) }

local WAVE = {
	-- forearm out (tilted away from the head) / in (tilted over toward it)
	outElbow = { 0, 0, 25 },
	inElbow = { 0, 0, 70 },
	-- the shoulder's small counter-swing, two frames behind the forearm
	outShoulder = { -10, 45, -6 },
	inShoulder = { -10, 45, 4 },
	outWrist = { 0, 0, -15 },
	inWrist = { 0, 0, 15 },
}

local FRAMES = {
	[0] = pose({
		Root = 0,
		Waist = { 0, 0, 0 },
		Neck = { 0, 0, 0 },
		RightShoulder = SIDE.shoulder,
		RightElbow = SIDE.elbow,
		LeftShoulder = LEFT_SIDE.shoulder,
		LeftElbow = LEFT_SIDE.elbow,
	}),
	-- ANTICIPATION: dip, lean away, arm cocked low
	[f(5)] = pose({
		Root = -0.05,
		Waist = { -6, -6, -5 },
		Neck = { -4, 0, 0 },
		RightShoulder = { 0, 25, -45 },
		RightElbow = { 0, 0, 45 },
		LeftShoulder = mirror({ 0, 0, -66 }),
		LeftElbow = LEFT_SIDE.elbow,
	}),
	-- HELLO: up out of the dip, arm up with the forearm standing, lean to the off side, head tilted in
	[f(12)] = pose({
		ease = "out",
		Root = 0,
		Waist = { 6, 6, 9 },
		Neck = { 6, -4, -10 },
		RightShoulder = { -10, 45, 0 },
		RightElbow = { 0, 0, 45 },
		RightWrist = { 0, 0, 0 },
		LeftShoulder = mirror({ 0, -10, -60 }),
		LeftElbow = mirror({ 0, 0, 30 }),
	}),
	-- down: the arm drops, elbow still soft
	[f(52)] = pose({
		Root = -0.02,
		Waist = { -2, 2, 2 },
		Neck = { -4, -2, -4 },
		RightShoulder = { 0, 18, -30 },
		RightElbow = { 0, 0, 40 },
		RightWrist = { 0, 0, 0 },
		LeftShoulder = LEFT_SIDE.shoulder,
		LeftElbow = LEFT_SIDE.elbow,
	}),
	[f(63)] = pose({
		Root = 0,
		Waist = { 0, 0, 0 },
		Neck = { 0, 0, 0 },
		RightShoulder = SIDE.shoulder,
		RightElbow = SIDE.elbow,
		LeftShoulder = LEFT_SIDE.shoulder,
		LeftElbow = LEFT_SIDE.elbow,
	}),
}

-- The wave: the forearm keys (elbow, wrist) on the beat, the shoulder 2 frames behind, a bounce on every "out".
local BEATS = { 16, 21, 26, 31, 36, 41, 46 }
for i, n in BEATS do
	local out = i % 2 == 1
	local key = FRAMES[f(n)] or {}
	key.RightElbow = if out then WAVE.outElbow else WAVE.inElbow
	key.RightWrist = if out then WAVE.outWrist else WAVE.inWrist
	key.Root = if out then -0.035 else 0
	key.Waist = if out then { 4, 6, 12 } else { 6, 4, 6 }
	key.Neck = if out then { 6, -6, -12 } else { 4, -2, -6 }
	key.LeftShoulder = if out then mirror({ 0, -14, -58 }) else mirror({ 0, -6, -62 })
	key.LeftElbow = mirror({ 0, 0, 30 })
	FRAMES[f(n)] = pose(key)
	local lag = FRAMES[f(n + 2)] or {}
	lag.RightShoulder = if out then WAVE.outShoulder else WAVE.inShoulder
	FRAMES[f(n + 2)] = lag
end

local SKIP = { ease = true }

local function build(name, frames)
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = false
	ks.Priority = Enum.AnimationPriority.Action
	local times = {}
	for t in frames do
		table.insert(times, t)
	end
	table.sort(times)
	for _, t in times do
		local frame = frames[t]
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local poses, keyed = {}, {}
		local function at(part)
			if poses[part] then
				return poses[part]
			end
			local p = Instance.new("Pose")
			p.Name = part
			p.Weight = 1
			local parent = PARENT[part]
			p.Parent = if parent then at(parent) else kf
			poses[part] = p
			return p
		end
		local key = frame.ease or "inout"
		at("HumanoidRootPart")
		for joint, d in frame do
			if SKIP[joint] then
				continue
			end
			local p
			if joint == "Root" then
				p = at("LowerTorso")
				p.CFrame = CFrame.new(0, d, 0)
				keyed.LowerTorso = true
			else
				p = at(JOINT_PART[joint])
				p.CFrame = turn(d)
				keyed[JOINT_PART[joint]] = true
			end
			p.EasingStyle = EASE[key][1]
			p.EasingDirection = EASE[key][2]
		end
		for part, p in poses do
			if not keyed[part] then
				p.Weight = 0
			end
		end
		kf.Parent = ks
	end
	return ks
end

local RS = game:GetService("ReplicatedStorage")
local old = RS:FindFirstChild("ClaudeCoachWave")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "ClaudeCoachWave"
build("CoachWave", FRAMES).Parent = folder
folder.Parent = RS
return "built CoachWave (v2)"
