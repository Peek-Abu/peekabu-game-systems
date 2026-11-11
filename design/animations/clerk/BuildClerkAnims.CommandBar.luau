--[[
	The Supply Counter clerk's two generic clips (owner 11-11, "Stamp & Stack"; v5: the polish pass, measured on every
	employee against design/animations/clerk/GATES.md by MeasureClerkAnims.CommandBar.luau), authored as
	KeyframeSequences on the shared employee kit rig (R15 joint names; the kit rig rests in a T-pose, arms out along X).
	No ears and no per-character parts, so every employee can play them. Key times are on the 30 fps grid (f(n) = n/30).

	- ClerkStamp (2.6 s, looped):
	  READY (f0) -> LOAD (f9) a small knee dip, the torso already arching -> the arm starts up 3 frames after the pelvis
	  (f3), accelerating until f15 and braking into -> PEAK (f21): legs straight again (the rise), arched back and rolled
	  away, the stamp high beside the head (the kit's arms are short and its heads big: the arm stays straight and the
	  torso rolls away so the stamp clears even Prickles' head) -> STRIKE (f21-f26) accelerating into the contact ->
	  IMPACT (f26, marker "Thunk"): the arm locks on the parcel (Constant) while the body keeps sinking to its lowest
	  point at f29 and the head nods through -> LIFT (f31, marker "Lift": the code hops the parcel now that the stamp is
	  off it) -> an overshoot (f39) -> CHECK (f50): turn and look down at the stamped parcel, a satisfied nod (f58) ->
	  settle (f66) -> READY (f78). The loop seam arrives and leaves at rest, so it never pops.
	- ClerkGreet (2.2 s): a big lean in over the counter, then three waves where the whole torso rocks with the arm
	  (out: upright, the arm out; in: rocked 26 deg, the arm lower), then the stamp's ready pose.

	Joint turns are degrees about X, Y, Z (CFrame.Angles order) over the rest pose (EmployeePoseRegistry's convention):
	X pitches (+ tips the top back), Y yaws (+ swings the right arm forward), Z roll (+ raises the right arm). The left
	side mirrors the right: (x, -y, -z). `Root` drops the LowerTorso in studs; the legs are solved for it (two-bone, the
	kit's average thigh/shin, the hip angle scaled by HIP_SCALE, measured to keep every employee's feet within 0.031
	studs) and the ankles keep the soles flat. A key without `Root` leaves the legs and pelvis free (interpolating).

	Easing: every key eases in and out unless the key says otherwise. `ease = "in"` accelerates into the next key (a
	strike, or the first half of a pass-through), `"out"` decelerates into it (the second half of a pass-through),
	`"const"` holds until the next key that has that joint. `easeJ` overrides one joint's easing on that key.
	`armOnly` keys only the joints listed (no left-arm rest fill). Poses a key does not list get Weight 0 (unkeyed).

	The stamp prop and the parcel are code (the clerk system), not part of the clip; MeasureClerkAnims documents the
	grip and the parcel rule the measurement assumed.

	Run in the Studio command bar (Edit). It writes ReplicatedStorage.ClaudeClerkAnims (ClerkStamp, ClerkGreet) for the
	measurement, the preview or the upload. Delete it after.
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

-- The kit's average thigh and shin (hip->knee, knee->ankle) over Pippa, Cappy and Prickles (studs).
local THIGH, SHIN = 0.31, 0.373
local HIP_SCALE = 0.93

-- Hip flex, knee flex (degrees) that keep the foot under the hip with the pelvis `drop` studs lower.
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
	const = { Enum.PoseEasingStyle.Constant, Enum.PoseEasingDirection.In },
}

local LEFT_REST = { shoulder = mirror({ 0, 52, -62 }), elbow = mirror({ 0, 38, 0 }) }
-- Fills the left-arm rest (unless armOnly) and solves the legs for the key's Root drop (only when it has one).
local function pose(t)
	if not t.armOnly then
		t.LeftShoulder = t.LeftShoulder or LEFT_REST.shoulder
		t.LeftElbow = t.LeftElbow or LEFT_REST.elbow
	end
	if t.Root ~= nil then
		local hip, knee = legs(-t.Root)
		t.RightHip, t.LeftHip = { -hip, 0, 0 }, { -hip, 0, 0 }
		t.RightKnee, t.LeftKnee = { knee, 0, 0 }, { knee, 0, 0 }
		t.RightAnkle, t.LeftAnkle = { hip - knee, 0, 0 }, { hip - knee, 0, 0 }
	end
	return t
end

local READY = {
	Root = 0,
	Waist = { 0, 0, 0 },
	Neck = { -8, 0, 0 },
	RightShoulder = { 0, 55, -20 },
	RightElbow = { 0, 0, 75 },
}
local function ready(extra)
	local t = table.clone(READY)
	for k, v in extra or {} do
		t[k] = v
	end
	return pose(t)
end

-- The arm at the contact, locked (Constant) through the hold until the lift.
local CONTACT_ARM = { RightShoulder = { 0, 80, -15 }, RightElbow = { 0, 0, 20 } }

local STAMP = {
	-- READY (the loop seam): the torso leaves rest accelerating, the legs ease into the dip, the arm waits
	[0] = ready({ ease = "in", easeJ = { Root = "inout", RightShoulder = "inout", RightElbow = "inout" } }),
	[f(3)] = pose({
		armOnly = true,
		ease = "in",
		RightShoulder = READY.RightShoulder,
		RightElbow = READY.RightElbow,
	}),
	-- LOAD: the knee dip
	[f(9)] = pose({ armOnly = true, Root = -0.05 }),
	-- the wind-up's pass-through (progress proportional to time), then a 6-frame braking arrival at the peak
	[f(15)] = pose({
		armOnly = true,
		ease = "out",
		Waist = { 13.6, -10.7, 22 },
		Neck = { 7, -7.8, -3.6 },
		RightShoulder = { 0, 16, 13 },
		RightElbow = { 0, 0, 25 },
	}),
	-- PEAK: legs straight (the rise), arched back and rolled away, the stamp high beside the head; the strike
	-- accelerates from here into the contact
	[f(21)] = pose({
		ease = "in",
		Root = 0,
		Waist = { 19, -15, 31 },
		Neck = { 13, -11, -5 },
		RightShoulder = { 0, -3, 29 },
		RightElbow = { 0, 0, 0 },
	}),
	-- IMPACT: the stamp lands on the parcel; the arm locks, the body keeps sinking
	[f(26)] = pose({
		ease = "out",
		easeJ = { RightShoulder = "const", RightElbow = "const" },
		Root = -0.12,
		Waist = { -24, 6, 0 },
		Neck = { -18, 0, 0 },
		RightShoulder = CONTACT_ARM.RightShoulder,
		RightElbow = CONTACT_ARM.RightElbow,
	}),
	-- the lowest point, after the contact: deeper squash, the head nods through
	[f(29)] = pose({ armOnly = true, Root = -0.16, Waist = { -25.5, 7, -1 }, Neck = { -30, 3, 0 } }),
	-- LIFT: the stamp leaves the parcel (the core is free here, so it never stops and restarts)
	[f(31)] = pose({ armOnly = true, RightShoulder = CONTACT_ARM.RightShoulder, RightElbow = CONTACT_ARM.RightElbow }),
	-- recover with an overshoot (the torso tips back past upright, the head bobs)
	[f(39)] = pose({
		Root = -0.02,
		Waist = { 6, 0, 0 },
		Neck = { 2, 8, 0 },
		RightShoulder = { 0, 50, -30 },
		RightElbow = { 0, 0, 55 },
	}),
	-- CHECK: turn to the stamped parcel and look down at it
	[f(50)] = pose({
		Root = -0.04,
		Waist = { -10, -18, 0 },
		Neck = { -16, -16, 4 },
		RightShoulder = { 0, 50, -32 },
		RightElbow = { 0, 0, 60 },
		LeftShoulder = mirror({ 0, 44, -58 }),
		LeftElbow = mirror({ 0, 30, 0 }),
	}),
	-- a satisfied nod (the head dips and comes back while the torso starts home)
	[f(58)] = pose({ armOnly = true, Neck = { -24, -12, 2 } }),
	[f(66)] = pose({
		Root = -0.02,
		Waist = { -2, 6, 0 },
		Neck = { -4, 6, 0 },
		RightShoulder = { 0, 52, -24 },
		RightElbow = { 0, 0, 70 },
		LeftShoulder = mirror({ 0, 54, -62 }),
		LeftElbow = mirror({ 0, 40, 0 }),
	}),
	-- back to READY, arriving at rest (the seam)
	[f(78)] = ready(),
}
local STAMP_MARKERS = { [f(26)] = "Thunk", [f(31)] = "Lift" }

-- The wave: out = upright, the arm out; in = rocked 26 deg, the arm lower (both clear every employee's head).
local WAVE = {
	outWaist = { -14, 0, 0 },
	inWaist = { -14, 0, 26 },
	outNeck = { -6, 0, 8 },
	inNeck = { -6, 0, -8 },
	outShoulder = { 0, -20, 28 },
	inShoulder = { 0, -20, 15 },
	outElbow = { 0, 0, 0 },
	inElbow = { 0, 0, 6 },
}
local GREET = {
	[0] = ready(),
	-- a big lean in over the counter, head tilted, arm going up
	[f(10)] = pose({
		Waist = { -28, 0, 0 },
		Neck = { -6, 0, 14 },
		RightShoulder = { 0, -20, 30 },
		RightElbow = { 0, 0, 10 },
	}),
	[f(66)] = ready(),
}
for i, n in { 18, 25, 33, 40, 48 } do
	local out = i % 2 == 1
	GREET[f(n)] = pose({
		Waist = if out then WAVE.outWaist else WAVE.inWaist,
		Neck = if out then WAVE.outNeck else WAVE.inNeck,
		RightShoulder = if out then WAVE.outShoulder else WAVE.inShoulder,
		RightElbow = if out then WAVE.outElbow else WAVE.inElbow,
	})
end

local SKIP = { ease = true, easeJ = true, armOnly = true }

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
		local frame = frames[t]
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local poses = {}
		local keyed = {}
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
		local function ease(p, joint)
			local key = (frame.easeJ and frame.easeJ[joint]) or frame.ease or "inout"
			p.EasingStyle = EASE[key][1]
			p.EasingDirection = EASE[key][2]
		end
		at("HumanoidRootPart")
		for joint, d in frame do
			if SKIP[joint] then
				continue
			end
			if joint == "Root" then
				local p = at("LowerTorso")
				p.CFrame = CFrame.new(0, d, 0)
				ease(p, "Root")
				keyed.LowerTorso = true
			else
				local p = at(JOINT_PART[joint])
				p.CFrame = turn(d)
				-- the legs follow the Root's easing so the feet stay under the hips
				ease(p, if joint:find("Hip") or joint:find("Knee") or joint:find("Ankle") then "Root" else joint)
				keyed[JOINT_PART[joint]] = true
			end
		end
		-- a pose that only parents others is unkeyed (Weight 0), so it never pins that joint
		for part, p in poses do
			if not keyed[part] then
				p.Weight = 0
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
return "built ClerkStamp, ClerkGreet (v5)"
