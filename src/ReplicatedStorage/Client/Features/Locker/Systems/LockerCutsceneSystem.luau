--!strict
--[=[
	LockerCutsceneSystem: drives the Stage-2 3D Lost & Found Locker opening cutscene on a client-local clone of
	`ReplicatedStorage.Assets.CleanupCrew.LockerStage` (or `Workspace.LockerStage_Ref` when all parts are present),
	guided by `LockerViewModel.cutscenePose` (design:
	docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	- Cloning `LockerStage` on the client keeps every part and light resident at `STAGE_ORIGIN` even when
	  `Workspace.StreamingEnabled` is on and the player's character is at the depot.
	- Binds at `Enum.RenderPriority.Camera.Value + 50` so the cutscene camera runs after `CameraServiceClient`.
	- Dresses the player's own employee (`EmployeePreviewSystem.outfit`) and places them in the Lost & Found room.
	- Animates the 4 camera beats (establishing -> approach with key -> key flies into keyhole & turns -> door bursts
	  open with rarity cavity light and volumetric neon beams).
	- Restores the camera and destroys temporary instances cleanly on finish or Skip.
	- Returns `nil` from `start` when the 3D stage is absent so `LockerOpeningScreen` falls back to Stage 1.

	Instance/Camera/RunService shell (exempt; timeline, camera, key and door poses specced in `LockerViewModel.spec`).

	@class LockerCutsceneSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CosmeticOutfitRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticOutfitRules)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)
local EmployeePreviewSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePreviewSystem)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local LockerViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Locker.LockerViewModel)

local BIND_NAME = "LockerCutsceneCamera"

local LockerCutsceneSystem = {}

local doorRest: { [Instance]: { [BasePart]: CFrame } } = {}

local function acquireStage(): (Model?, boolean)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local cc = if assets ~= nil then assets:FindFirstChild("CleanupCrew") else nil
	local template = if cc ~= nil then cc:FindFirstChild("LockerStage") else nil
	if template ~= nil and template:IsA("Model") then
		local existingRef = workspace:FindFirstChild("LockerStage_Ref")
		if existingRef ~= nil then
			existingRef:Destroy()
		end
		local copy = template:Clone()
		copy.Name = "LockerStage_Active"
		copy.Parent = workspace
		return copy, true
	end
	local inWorkspace = workspace:FindFirstChild("LockerStage_Ref")
	if inWorkspace ~= nil and inWorkspace:IsA("Model") then
		return inWorkspace, false
	end
	return nil, false
end

local function setDoorAngle(lockerModel: Model, deg: number)
	local door = lockerModel:FindFirstChild("Door")
	local hinge = lockerModel:FindFirstChild("HingePivot")
	if door == nil or hinge == nil or not hinge:IsA("BasePart") then
		return
	end
	local rest = doorRest[lockerModel]
	if rest == nil then
		rest = {}
		for _, descendant in door:GetDescendants() do
			if descendant:IsA("BasePart") then
				local closed = descendant:GetAttribute("Closed")
				rest[descendant] = if typeof(closed) == "CFrame" then closed else descendant.CFrame
			end
		end
		doorRest[lockerModel] = rest
	end
	local pivot = hinge.CFrame
	local rot = pivot * CFrame.Angles(0, math.rad(-deg), 0) * pivot:Inverse()
	for part, cf in rest do
		part.CFrame = rot * cf
	end
end

local function setBurstGlow(lockerModel: Model, on: boolean, color: Color3)
	local cavity = lockerModel:FindFirstChild("Cavity")
	if cavity == nil or not cavity:IsA("BasePart") then
		return
	end
	cavity.Color = color
	local light = cavity:FindFirstChild("BurstLight")
	if light == nil or not light:IsA("PointLight") then
		local created = Instance.new("PointLight")
		created.Name = "BurstLight"
		created.Parent = cavity
		light = created
	end
	if light ~= nil and light:IsA("PointLight") then
		light.Color = color
		light.Range = if on then 22 else 0
		light.Brightness = if on then 6 else 0
	end
	local existingBeams = lockerModel:FindFirstChild("Beams")
	if existingBeams ~= nil then
		existingBeams:Destroy()
	end
	if on then
		local beams = Instance.new("Model")
		beams.Name = "Beams"
		beams.Parent = lockerModel
		local base = cavity.CFrame * CFrame.new(0, 0.4, -0.3)
		for index = 1, 7 do
			local angle = (index - 4) * 0.22
			local ray = Instance.new("Part")
			ray.Name = "Ray"
			ray.Anchored = true
			ray.CanCollide = false
			ray.CastShadow = false
			ray.Material = Enum.Material.Neon
			ray.Color = color
			ray.Transparency = 0.55 + math.abs(index - 4) * 0.08
			ray.Size = Vector3.new(0.5 + (index % 2) * 0.4, 0.15, 9)
			ray.CFrame = base * CFrame.Angles(math.rad(10 + (index % 3) * 7), angle * 1.4, 0) * CFrame.new(0, 0, -4.5)
			ray.Parent = beams
		end
	end
end

local function buildActor(): Model?
	local entitlements = StateSyncClientStore.entitlements()
	local loadout = StateSyncClientStore.loadout()
	local outfit = CosmeticOutfitRules.current(loadout, function(id: string): boolean
		return CosmeticRules.owns(entitlements, id)
	end)
	local localPlayer = Players.LocalPlayer
	local character = if localPlayer ~= nil then localPlayer.Character else nil
	local model = EmployeePreviewSystem.outfit(outfit, ReplicatedStorage, character, false)
	return model
end

function LockerCutsceneSystem.start(outcome: LockerTypes.Outcome): (() -> ())?
	local stage, ownedStage = acquireStage()
	local camera = workspace.CurrentCamera
	if stage == nil or camera == nil then
		return nil
	end
	local lockerName = if outcome.locker == "gleam" then "GleamLocker" else "GloomLocker"
	local keyName = if outcome.locker == "gleam" then "GleamKey" else "GloomKey"
	local lockerModel = stage:FindFirstChild(lockerName)
	local propsFolder = stage:FindFirstChild("Props")
	local keyModel = if propsFolder ~= nil then propsFolder:FindFirstChild(keyName) else nil
	if lockerModel == nil or not lockerModel:IsA("Model") or lockerModel:FindFirstChild("Door") == nil then
		if ownedStage then
			stage:Destroy()
		end
		return nil
	end

	local origin = LockerViewModel.STAGE_ORIGIN
	local rarityShade = UIToonConstants.rarity(outcome.rarity)
	local savedCameraType = camera.CameraType
	local savedCameraCFrame = camera.CFrame
	local savedFov = camera.FieldOfView

	local crewFolder = stage:FindFirstChild("Crew")
	local hiddenParts: { [BasePart]: number } = {}
	if crewFolder ~= nil then
		for _, descendant in crewFolder:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				hiddenParts[descendant] = descendant.Transparency
				descendant.Transparency = 1
			end
		end
	end

	local actor = buildActor()
	if actor ~= nil then
		actor.Parent = stage
	end

	local startedAt = os.clock()
	local duration = LockerViewModel.OPENING_DURATION
	local glowActive = false

	local function applyAt(alpha: number)
		local pose = LockerViewModel.cutscenePose(outcome.locker, alpha)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = pose.fov
		camera.CFrame =
			CFrame.lookAt((origin * CFrame.new(pose.camPos)).Position, (origin * CFrame.new(pose.camLook)).Position)
		if actor ~= nil then
			actor:PivotTo(origin * pose.employeeCFrame)
		end
		if keyModel ~= nil and keyModel:IsA("Model") then
			keyModel:PivotTo(origin * pose.keyCFrame)
		end
		setDoorAngle(lockerModel, pose.doorDeg)
		if pose.glow ~= glowActive then
			glowActive = pose.glow
			setBurstGlow(lockerModel, glowActive, rarityShade.hi)
		end
	end

	pcall(function()
		RunService:UnbindFromRenderStep(BIND_NAME)
	end)
	applyAt(0)
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 50, function()
		local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
		applyAt(alpha)
	end)

	return function()
		pcall(function()
			RunService:UnbindFromRenderStep(BIND_NAME)
		end)
		doorRest[lockerModel] = nil
		if ownedStage then
			stage:Destroy()
		else
			setDoorAngle(lockerModel, 0)
			setBurstGlow(lockerModel, false, rarityShade.hi)
			if keyModel ~= nil and keyModel:IsA("Model") then
				keyModel:PivotTo(CFrame.new(0, -100, 0))
			end
			if actor ~= nil then
				actor:Destroy()
			end
			for part, transparency in hiddenParts do
				part.Transparency = transparency
			end
		end
		camera.CameraType = savedCameraType
		camera.FieldOfView = savedFov
		camera.CFrame = savedCameraCFrame
	end
end

return LockerCutsceneSystem
