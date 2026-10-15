--!strict
--[=[
	AnimationCarryRigHarness: the test carriers the carry validator (AnimationCarryHarness) holds every template on.

	- `employee`: the default employee (Pippa), from her art template exactly as EmployeeSpawnSystem installs her
	  (prepared, then scaled to her registry scale), with her own idle and walk.
	- `stockR15`: a stock R15 avatar from the engine's default HumanoidDescription proportions (dumped 2026-10-15),
	  joined by BuildRigFromAttachments: in this place that gives the upgraded avatar joints (AnimationConstraints with
	  BallSocketConstraint limits), as a real stock avatar has, with the stock idle and walk.
	Both are built in the `CarryHarness` folder, far from any map, root anchored.

	@class AnimationCarryRigHarness
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared.Features
local AnimationRegistry = require(Shared.Animation.Data.AnimationRegistry)
local EmployeeRegistry = require(Shared.Employee.Data.EmployeeRegistry)
local EmployeeSpawnSystem = require(ServerScriptService.Features.Employee.Systems.EmployeeSpawnSystem)

export type Carrier = { name: string, model: Model, idle: string?, walk: string? }

local AnimationCarryRigHarness = {}

-- Where the carriers are built, far from any map.
local ORIGIN = Vector3.new(0, 4000, 0)

-- A stock R15 avatar (Players:CreateHumanoidModelFromDescription with a default HumanoidDescription, dumped
-- 2026-10-15): part sizes and rig attachments, joined by BuildRigFromAttachments.
local R15_HIP = 2.1924
local R15_PARTS: { [string]: { size: Vector3, attachments: { [string]: CFrame } } } = {
	HumanoidRootPart = { size = Vector3.new(2, 2, 1), attachments = { RootRigAttachment = CFrame.new(0, -1, 0) } },
	LowerTorso = {
		size = Vector3.new(1.9914, 0.4007, 1.004),
		attachments = {
			RootRigAttachment = CFrame.new(0, -0.2, 0),
			WaistRigAttachment = CFrame.new(0, 0.2, 0),
			LeftHipRigAttachment = CFrame.new(-0.5, -0.2, 0),
			RightHipRigAttachment = CFrame.new(0.5, -0.2, 0),
		},
	},
	UpperTorso = {
		size = Vector3.new(1.9432, 1.698, 1.004),
		attachments = {
			WaistRigAttachment = CFrame.new(0, -0.849, 0),
			NeckRigAttachment = CFrame.new(0, 0.849, 0),
			LeftShoulderRigAttachment = CFrame.new(-0.9716, 0.5975, 0),
			RightShoulderRigAttachment = CFrame.new(0.9716, 0.5975, 0),
		},
	},
	Head = { size = Vector3.new(1.159, 1.182, 1.1606), attachments = { NeckRigAttachment = CFrame.new(0, -0.5758, 0) } },
	LeftUpperArm = {
		size = Vector3.new(1.0011, 1.2416, 1.0019),
		attachments = {
			LeftShoulderRigAttachment = CFrame.new(0.5005, 0.4189, 0),
			LeftElbowRigAttachment = CFrame.new(0.0005, -0.3549, 0),
		},
	},
	RightUpperArm = {
		size = Vector3.new(1.0011, 1.2416, 1.0019),
		attachments = {
			RightShoulderRigAttachment = CFrame.new(-0.5005, 0.4189, 0),
			RightElbowRigAttachment = CFrame.new(0, -0.355, 0),
		},
	},
	LeftLowerArm = {
		size = Vector3.new(1.0011, 1.1175, 1.0019),
		attachments = {
			LeftElbowRigAttachment = CFrame.new(0.0005, 0.2748, 0),
			LeftWristRigAttachment = CFrame.new(0.0005, -0.5322, 0),
		},
	},
	RightLowerArm = {
		size = Vector3.new(1.0011, 1.1175, 1.0019),
		attachments = {
			RightElbowRigAttachment = CFrame.new(0, 0.2747, 0),
			RightWristRigAttachment = CFrame.new(0, -0.5322, 0),
		},
	},
	LeftHand = {
		size = Vector3.new(0.9843, 0.3158, 1.0283),
		attachments = {
			LeftWristRigAttachment = CFrame.new(0.0005, 0.1316, 0),
			LeftGripAttachment = CFrame.new(0, -0.1578, 0) * CFrame.Angles(-math.pi / 2, 0, 0),
		},
	},
	RightHand = {
		size = Vector3.new(0.9843, 0.3158, 1.0283),
		attachments = {
			RightWristRigAttachment = CFrame.new(0, 0.1316, 0),
			RightGripAttachment = CFrame.new(0, -0.1578, 0) * CFrame.Angles(-math.pi / 2, 0, 0),
		},
	},
	LeftUpperLeg = {
		size = Vector3.new(0.9928, 1.3629, 0.9727),
		attachments = {
			LeftHipRigAttachment = CFrame.new(0, 0.4714, 0),
			LeftKneeRigAttachment = CFrame.new(0, -0.4493, 0),
		},
	},
	RightUpperLeg = {
		size = Vector3.new(0.9928, 1.3629, 0.9727),
		attachments = {
			RightHipRigAttachment = CFrame.new(0, 0.4714, 0),
			RightKneeRigAttachment = CFrame.new(0, -0.4492, 0),
		},
	},
	LeftLowerLeg = {
		size = Vector3.new(0.9928, 1.3007, 0.9728),
		attachments = {
			LeftKneeRigAttachment = CFrame.new(0, 0.4132, 0),
			LeftAnkleRigAttachment = CFrame.new(0, -0.5965, 0),
		},
	},
	RightLowerLeg = {
		size = Vector3.new(0.9928, 1.3007, 0.9728),
		attachments = {
			RightKneeRigAttachment = CFrame.new(0, 0.4134, 0),
			RightAnkleRigAttachment = CFrame.new(0, -0.5965, 0),
		},
	},
	LeftFoot = {
		size = Vector3.new(1.0089, 0.312, 1.0011),
		attachments = { LeftAnkleRigAttachment = CFrame.new(0, 0.106, 0) },
	},
	RightFoot = {
		size = Vector3.new(1.0089, 0.312, 1.0011),
		attachments = { RightAnkleRigAttachment = CFrame.new(0, 0.106, 0) },
	},
}

--[=[
	Waits `frames` Heartbeats (for the Animator to apply a change).
]=]
function AnimationCarryRigHarness.settle(frames: number)
	for _ = 1, frames do
		RunService.Heartbeat:Wait()
	end
end

--[=[
	The folder the harness builds in.
]=]
function AnimationCarryRigHarness.folder(): Folder
	local existing = Workspace:FindFirstChild("CarryHarness")
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "CarryHarness"
	made.Parent = Workspace
	return made
end

--[=[
	`model`'s Animator, made when it has none.
]=]
function AnimationCarryRigHarness.animator(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	local found = humanoid:FindFirstChildOfClass("Animator")
	if found ~= nil then
		return found
	end
	local made = Instance.new("Animator")
	made.Parent = humanoid
	return made
end

-- Stands `model` (root anchored) at `at`.
local function stand(model: Model, at: Vector3)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		root.Anchored = true
		model.PrimaryPart = root
		model:PivotTo(CFrame.new(at))
	end
end

--[=[
	A stock R15 avatar at `at` (see R15_PARTS), parented to the harness folder.
]=]
function AnimationCarryRigHarness.stockR15(at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "StockR15"
	for name, spec in R15_PARTS do
		local bodyPart = Instance.new("Part")
		bodyPart.Name = name
		bodyPart.Size = spec.size
		bodyPart.CanCollide = false
		bodyPart.Transparency = if name == "HumanoidRootPart" then 1 else 0
		for attachmentName, frame in spec.attachments do
			local attachment = Instance.new("Attachment")
			attachment.Name = attachmentName
			attachment.CFrame = frame
			attachment.Parent = bodyPart
		end
		bodyPart.Parent = model
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = R15_HIP
	humanoid.Parent = model
	model.Parent = AnimationCarryRigHarness.folder()
	humanoid:BuildRigFromAttachments()
	AnimationCarryRigHarness.animator(model)
	stand(model, at)
	return model
end

--[=[
	The default employee (Pippa) at `at`, from its art template as EmployeeSpawnSystem installs it (prepared, then
	scaled to its registry scale). Nil when the place has no template (a test place without the art).
]=]
function AnimationCarryRigHarness.employee(at: Vector3): Model?
	local def = EmployeeRegistry.get(EmployeeRegistry.DEFAULT)
	if def == nil then
		return nil
	end
	local current: Instance? = ReplicatedStorage
	for _, name in def.templatePath do
		current = if current ~= nil then current:FindFirstChild(name) else nil
	end
	if current == nil or not current:IsA("Model") then
		return nil
	end
	local model = current:Clone()
	model.Name = def.name
	EmployeeSpawnSystem.prepare(model)
	model:ScaleTo(model:GetScale() * def.scale)
	model.Parent = AnimationCarryRigHarness.folder()
	AnimationCarryRigHarness.animator(model)
	stand(model, at)
	return model
end

-- The asset id of an AnimationRegistry key.
local function clip(key: string?): string?
	local def = if key ~= nil then AnimationRegistry.get(key) else nil
	return if def ~= nil then def.assetId else nil
end

--[=[
	The test carriers that this place can build: Pippa (with her own idle and walk) and a stock R15 (the stock idle
	and walk). `only` limits them by name.
]=]
function AnimationCarryRigHarness.carriers(only: { string }?): { Carrier }
	local carriers: { Carrier } = {}
	local function wanted(name: string): boolean
		return only == nil or table.find(only, name) ~= nil
	end
	if wanted("Pippa") then
		local pippa = AnimationCarryRigHarness.employee(ORIGIN)
		local def = EmployeeRegistry.get(EmployeeRegistry.DEFAULT)
		local locomotion = if def ~= nil then def.locomotion else nil
		if pippa ~= nil then
			table.insert(carriers, {
				name = "Pippa",
				model = pippa,
				idle = clip(if locomotion ~= nil then locomotion.idle else nil),
				walk = clip(if locomotion ~= nil then locomotion.walk else nil),
			})
		end
	end
	if wanted("StockR15") then
		table.insert(carriers, {
			name = "StockR15",
			model = AnimationCarryRigHarness.stockR15(ORIGIN + Vector3.new(40, 0, 0)),
			idle = clip("idle"),
			walk = clip("walk"),
		})
	end
	return carriers
end

return AnimationCarryRigHarness
