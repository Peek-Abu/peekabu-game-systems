local CLIPS = {
SofaDoze={loop=true,markers={},frames={[0]={Waist={18,0,0},Neck={-40,0,0},RightHip={88,0,4},LeftHip={88,0,-4},RightKnee={-86,0,0},LeftKnee={-86,0,0},RightAnkle={0,0,0},LeftAnkle={0,0,0},RightShoulder={0,50,-78},RightElbow={0,0,74},LeftShoulder={0,-50,78},LeftElbow={0,0,-74}},[1.5]={Waist={21,0,0},Neck={-35,0,4},RightHip={88,0,4},LeftHip={88,0,-4},RightKnee={-86,0,0},LeftKnee={-86,0,0},RightAnkle={0,0,0},LeftAnkle={0,0,0},RightShoulder={0,50,-78},RightElbow={0,0,74},LeftShoulder={0,-50,78},LeftElbow={0,0,-74}},[3]={Waist={18,0,0},Neck={-40,0,0},RightHip={88,0,4},LeftHip={88,0,-4},RightKnee={-86,0,0},LeftKnee={-86,0,0},RightAnkle={0,0,0},LeftAnkle={0,0,0},RightShoulder={0,50,-78},RightElbow={0,0,74},LeftShoulder={0,-50,78},LeftElbow={0,0,-74}},[4.5]={Waist={18.5,0,0},Neck={-54,0,-6},RightHip={88,0,4},LeftHip={88,0,-4},RightKnee={-86,0,0},LeftKnee={-86,0,0},RightAnkle={0,0,0},LeftAnkle={0,0,0},RightShoulder={0,50,-78},RightElbow={0,0,74},LeftShoulder={0,-50,78},LeftElbow={0,0,-74},ease="in"},[4.9]={Waist={19,0,0},Neck={-14,0,3},RightHip={88,0,4},LeftHip={88,0,-4},RightKnee={-86,0,0},LeftKnee={-86,0,0},RightAnkle={0,0,0},LeftAnkle={0,0,0},RightShoulder={0,50,-78},RightElbow={0,0,74},LeftShoulder={0,-50,78},LeftElbow={0,0,-74},ease="out"},[5.5]={Waist={18,0,0},Neck={-28,0,0},RightHip={88,0,4},LeftHip={88,0,-4},RightKnee={-86,0,0},LeftKnee={-86,0,0},RightAnkle={0,0,0},LeftAnkle={0,0,0},RightShoulder={0,50,-78},RightElbow={0,0,74},LeftShoulder={0,-50,78},LeftElbow={0,0,-74}},[6]={Waist={18,0,0},Neck={-40,0,0},RightHip={88,0,4},LeftHip={88,0,-4},RightKnee={-86,0,0},LeftKnee={-86,0,0},RightAnkle={0,0,0},LeftAnkle={0,0,0},RightShoulder={0,50,-78},RightElbow={0,0,74},LeftShoulder={0,-50,78},LeftElbow={0,0,-74}}}},
SeatedWave={loop=false,markers={},frames={[0]={Neck={-40,0,0},RightShoulder={0,50,-78},RightElbow={0,0,74}},[0.266667]={ease="out",Neck={0,0,-8},Waist={12,0,6},RightShoulder={-10,45,0},RightElbow={0,0,45}},[0.4]={RightElbow={0,0,25},Neck={2,0,-10}},[0.466667]={RightShoulder={-10,45,-6}},[0.566667]={RightElbow={0,0,70},Neck={0,0,-4}},[0.633333]={RightShoulder={-10,45,4}},[0.733333]={RightElbow={0,0,25},Neck={2,0,-10}},[0.8]={RightShoulder={-10,45,-6}},[0.9]={RightElbow={0,0,70},Neck={0,0,-4}},[0.966667]={RightShoulder={-10,45,4}},[1.06667]={RightElbow={0,0,25},Neck={2,0,-10}},[1.13333]={RightShoulder={-10,45,-6}},[1.23333]={RightElbow={0,0,70},Neck={0,0,-4}},[1.3]={RightShoulder={-10,45,4}},[1.4]={RightElbow={0,0,25},Neck={2,0,-10}},[1.46667]={RightShoulder={-10,45,-6}},[1.73333]={Neck={-10,0,0},Waist={18,0,0},RightShoulder={0,40,-50},RightElbow={0,0,60}},[2]={Neck={-40,0,0},Waist={18,0,0},RightShoulder={0,50,-78},RightElbow={0,0,74}}}},
}
local PARENT = { LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso", RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm", RightHand = "RightLowerArm", LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm", LeftHand = "LeftLowerArm", RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg", RightFoot = "RightLowerLeg", LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg", LeftFoot = "LeftLowerLeg" }
local JOINT_PART = { Waist = "UpperTorso", Neck = "Head", RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm", RightWrist = "RightHand", LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm", LeftWrist = "LeftHand", RightHip = "RightUpperLeg", RightKnee = "RightLowerLeg", RightAnkle = "RightFoot", LeftHip = "LeftUpperLeg", LeftKnee = "LeftLowerLeg", LeftAnkle = "LeftFoot" }
local EASE = { inout = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.InOut }, ["in"] = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.In }, out = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.Out }, const = { Enum.PoseEasingStyle.Constant, Enum.PoseEasingDirection.In } }
local RS = game:GetService("ReplicatedStorage")
local old = RS:FindFirstChild("ClaudeLoungeClips") if old then old:Destroy() end
local dest = Instance.new("Folder") dest.Name = "ClaudeLoungeClips"
local report = {}
for name, clip in CLIPS do
	local ks = Instance.new("KeyframeSequence") ks.Name = name ks.Loop = clip.loop ks.Priority = Enum.AnimationPriority.Action
	local times = {} for t in clip.frames do table.insert(times, t) end table.sort(times)
	for _, t in times do
		local frame = clip.frames[t] local kf = Instance.new("Keyframe") kf.Time = t local poses, keyed = {}, {}
		local function at(part) if poses[part] then return poses[part] end local p = Instance.new("Pose") p.Name = part p.Weight = 1 local parent = PARENT[part] p.Parent = if parent then at(parent) else kf poses[part] = p return p end
		at("HumanoidRootPart")
		for joint, d in frame do
			if joint == "ease" or joint == "easeJ" then continue end
			local key = (frame.easeJ and frame.easeJ[joint]) or frame.ease or "inout"
			local p
			if joint == "Root" then p = at("LowerTorso") p.CFrame = CFrame.new(0, d, 0) keyed.LowerTorso = true
			else p = at(JOINT_PART[joint]) p.CFrame = CFrame.Angles(math.rad(d[1]), math.rad(d[2]), math.rad(d[3])) keyed[JOINT_PART[joint]] = true end
			p.EasingStyle = EASE[key][1] p.EasingDirection = EASE[key][2]
		end
		for part, p in poses do if not keyed[part] then p.Weight = 0 p.EasingStyle = Enum.PoseEasingStyle.Linear p.EasingDirection = Enum.PoseEasingDirection.In end end
		for _, m in clip.markers[t] or {} do local km = Instance.new("KeyframeMarker") km.Name = m kf:AddMarker(km) end
		kf.Parent = ks
	end
	local count, total = 0, 0
	for _, p in ks:GetDescendants() do if p:IsA("Pose") then count += 1 for _, v in { p.CFrame:GetComponents() } do total += math.round(v * 1000) / 1000 end total += p.EasingStyle.Value * 3 + p.EasingDirection.Value * 7 + p.Weight * 11 end end
	table.insert(report, string.format("%s: %d poses, %.2f", name, count, total))
	ks.Parent = dest
end
dest.Parent = RS
table.sort(report)
return table.concat(report, "
")