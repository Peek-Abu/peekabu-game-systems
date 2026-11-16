--!strict
--[=[
	LockerCutsceneSystem: drives the Stage-2 3D Lost & Found Locker opening cutscene on a client-local clone of
	`ReplicatedStorage.Assets.CleanupCrew.LockerStage` (or `Workspace.LockerStage_Ref` when all parts are present),
	guided by `LockerViewModel.cutscenePose` (design:
	docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	- Cloning `LockerStage` on the client keeps every part and light resident at `STAGE_ORIGIN` even when
	  `Workspace.StreamingEnabled` is on and the player's character is at the depot.
	- Binds at `Enum.RenderPriority.Camera.Value + 50` so the cutscene camera runs after `CameraServiceClient`.
	- Dresses the player's own employee (`EmployeePreviewSystem.outfit`) and places them in the Lost & Found room,
	  playing their own idle (a live preview), or held in their idle pose when no live slot is free (owner check 11-16:
	  they stood frozen with arms out).
	- Animates the beats (establishing -> approach with key -> key flies into keyhole & turns -> the shut door rattles
	  with the prize's colour leaking from its seams -> door bursts open, out toward the camera, with rarity cavity
	  light and volumetric neon beams). The rarer the prize, the longer the rattle, the more and brighter the leaking
	  light shafts and the burst's rays (LockerViewModel.RARITY_FX; owner picks 11-16).
	- Softens the stage's neon on its own client copy (key and lockers: Neon -> SmoothPlastic) and keeps the added
	  light (leak, rays) dim, so nothing blooms to white (owner 11-16: "lights are very neon on key / cutscene").
	- The leak is plain white through the hold and turns the prize's rarity colour in its last half second (pose
	  `leakTint`), a glimpse of the rarity before the door opens.
	- `hasStage()` answers, before anything renders, whether the 3D stage is there, so LockerOpeningScreen never draws
	  its 2D fallback for a frame first (owner 11-16: a screen flashed for about 0.1 s before the cutscene).
	- Plays the beats' sounds (LockerAssets: library picks, NOT approved): the key click, the rattle (louder the
	  rarer), the burst and the rarity's prize chime.
	- Restores the camera and destroys temporary instances cleanly on finish or Skip.
	- Returns `nil` from `start` when the 3D stage is absent so `LockerOpeningScreen` falls back to Stage 1.

	Instance/Camera/RunService shell (exempt; timeline, camera, key and door poses specced in `LockerViewModel.spec`).

	@class LockerCutsceneSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CosmeticOutfitRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticOutfitRules)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local EmployeePoseRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeePoseRegistry)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)
local EmployeePreviewSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePreviewSystem)
local LockerAssets = require(ReplicatedStorage.Client.Features.Locker.Data.LockerAssets)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local LockerViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Locker.LockerViewModel)

local BIND_NAME = "LockerCutsceneCamera"

-- Loaded for its registration: the cutscene's sounds exist before the first open.
local _sounds = LockerAssets.sounds

local LockerCutsceneSystem = {}

local doorRest: { [Instance]: { [BasePart]: CFrame } } = {}

-- The cutscene's stage template (ReplicatedStorage.Assets.CleanupCrew.LockerStage), nil when it is absent.
local function template(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local cc = if assets ~= nil then assets:FindFirstChild("CleanupCrew") else nil
	return if cc ~= nil then cc:FindFirstChild("LockerStage") else nil
end

-- Studio's Neon material blooms to white on camera; on the cutscene's own copy every Neon part (the key, the
-- lockers' glow bits) becomes SmoothPlastic in the same colour.
local function soften(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
			descendant.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function acquireStage(): (Model?, boolean)
	local source = template()
	if source ~= nil and source:IsA("Model") then
		local existingRef = workspace:FindFirstChild("LockerStage_Ref")
		if existingRef ~= nil then
			existingRef:Destroy()
		end
		local copy = source:Clone()
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
	-- Both doors hinge on their -X edge: a positive turn about +Y swings the door out toward the room (a negative one
	-- swung it back through the locker's body).
	local pivot = hinge.CFrame
	local rot = pivot * CFrame.Angles(0, math.rad(deg), 0) * pivot:Inverse()
	for part, cf in rest do
		part.CFrame = rot * cf
	end
end

local function setBurstGlow(lockerModel: Model, on: boolean, color: Color3, fx: LockerViewModel.RarityFx)
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
		light.Range = if on then 14 + 2 * fx.brightness else 0
		light.Brightness = if on then fx.brightness else 0
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
		local middle = (fx.rays + 1) / 2
		for index = 1, fx.rays do
			local angle = (index - middle) * (1.5 / math.max(1, fx.rays - 1))
			local ray = Instance.new("Part")
			ray.Name = "Ray"
			ray.Anchored = true
			ray.CanCollide = false
			ray.CastShadow = false
			ray.Material = Enum.Material.Neon
			ray.Color = color
			ray.Transparency = math.min(0.92, 0.7 + math.abs(index - middle) * (0.2 / middle))
			ray.Size = Vector3.new(0.5 + (index % 2) * 0.4, 0.15, 9)
			ray.CFrame = base * CFrame.Angles(math.rad(10 + (index % 3) * 7), angle * 1.4, 0) * CFrame.new(0, 0, -4.5)
			ray.Parent = beams
		end
	end
end

-- The light leaking round the shut door while it rattles: a glowing strip on the top, bottom and latch seams, `fx.lights`
-- shafts pointing out of them, and a light behind the door. Returns its update (leak 0..1, seconds) and its cleanup.
local function buildLeak(
	lockerModel: Model,
	fx: LockerViewModel.RarityFx
): (((leak: number, seconds: number, color: Color3) -> ())?, (() -> ())?)
	local door = lockerModel:FindFirstChild("Door")
	local cavity = lockerModel:FindFirstChild("Cavity")
	if door == nil or not door:IsA("Model") or cavity == nil or not cavity:IsA("BasePart") then
		return nil, nil
	end
	local cf, size = door:GetBoundingBox()
	local front = -size.Z / 2 - 0.04
	local halfX, halfY = size.X / 2, size.Y / 2
	local folder = Instance.new("Model")
	folder.Name = "Leak"
	local function neon(name: string, partSize: Vector3, at: CFrame): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = Color3.new(1, 1, 1)
		part.Transparency = 1
		part.Size = partSize
		part.CFrame = at
		part.Parent = folder
		return part
	end
	local strips = {
		neon("SeamTop", Vector3.new(size.X, 0.1, 0.1), cf * CFrame.new(0, halfY + 0.05, front)),
		neon("SeamBottom", Vector3.new(size.X, 0.1, 0.1), cf * CFrame.new(0, -halfY - 0.05, front)),
		neon("SeamLatch", Vector3.new(0.1, size.Y, 0.1), cf * CFrame.new(halfX + 0.05, 0, front)),
	}
	-- Shafts spread along the seams (top, latch side, bottom), each pointing out from the door's middle and toward
	-- the camera.
	local shafts: { Part } = {}
	for index = 1, fx.lights do
		local u = (index - 0.5) / fx.lights
		local spot: Vector3
		if u < 0.4 then
			spot = Vector3.new(-halfX + size.X * (u / 0.4), halfY, front)
		elseif u < 0.7 then
			spot = Vector3.new(halfX, halfY - size.Y * ((u - 0.4) / 0.3), front)
		else
			spot = Vector3.new(halfX - size.X * ((u - 0.7) / 0.3), -halfY, front)
		end
		local out = (Vector3.new(spot.X, spot.Y, 0).Unit + Vector3.new(0, 0, -0.6)).Unit
		local length = 1.2 + (index % 3) * 0.5
		local base = cf:PointToWorldSpace(spot)
		local tip = base + cf:VectorToWorldSpace(out) * length
		table.insert(shafts, neon("Shaft", Vector3.new(0.14, 0.14, length), CFrame.lookAt((base + tip) / 2, tip)))
	end
	local light = Instance.new("PointLight")
	light.Name = "LeakLight"
	light.Color = Color3.new(1, 1, 1)
	light.Range = 6 + fx.brightness * 0.5
	light.Brightness = 0
	light.Parent = cavity
	folder.Parent = lockerModel
	local function update(amount: number, seconds: number, color: Color3)
		for _, strip in strips do
			strip.Transparency = 1 - 0.55 * amount
			strip.Color = color
		end
		for index, shaft in shafts do
			local flicker = 0.75 + 0.25 * math.sin(seconds * 23 + index * 1.7)
			shaft.Transparency = 1 - math.clamp(amount * flicker * 0.45, 0, 0.45)
			shaft.Color = color
		end
		light.Color = color
		-- Dim: the seams and shafts carry the leak; a bright light here lit the whole locker up like neon (Play check).
		light.Brightness = fx.brightness * 0.18 * amount
	end
	local function cleanup()
		folder:Destroy()
		light:Destroy()
	end
	return update, cleanup
end

-- The player's own employee in their outfit: live and playing their idle when a live preview slot is free, else
-- frozen in their idle pose. Returns the model and whether it is live.
local function buildActor(): (Model?, boolean)
	local entitlements = StateSyncClientStore.entitlements()
	local loadout = StateSyncClientStore.loadout()
	local outfit = CosmeticOutfitRules.current(loadout, function(id: string): boolean
		return CosmeticRules.owns(entitlements, id)
	end)
	local localPlayer = Players.LocalPlayer
	local character = if localPlayer ~= nil then localPlayer.Character else nil
	local set = EmployeePoseRegistry.get(outfit.employee)
	local pose = if set ~= nil then set.poses.idle else nil
	local model, isLive = EmployeePreviewSystem.outfit(outfit, ReplicatedStorage, character, true, pose)
	if model ~= nil and isLive then
		-- Parented first: an Animator plays only in the world.
		model.Parent = workspace
		EmployeePreviewSystem.playIdle(model, outfit.employee, CosmeticRegistry.keyOf(outfit.look.skin))
	end
	return model, isLive
end

-- Whether the 3D stage can play (its template, or a Workspace.LockerStage_Ref, is there).
function LockerCutsceneSystem.hasStage(): boolean
	local found = template()
	if found ~= nil and found:IsA("Model") then
		return true
	end
	local ref = workspace:FindFirstChild("LockerStage_Ref")
	return ref ~= nil and ref:IsA("Model")
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

	local actor, actorLive = buildActor()
	if actor ~= nil then
		actor.Parent = stage
	end

	local fx = LockerViewModel.RARITY_FX[outcome.rarity]
	local startedAt = os.clock()
	local duration = LockerViewModel.openingDuration(outcome.rarity)
	local glowActive = false
	if ownedStage then
		soften(lockerModel)
		if keyModel ~= nil then
			soften(keyModel)
		end
		-- A soft warm fill over the camera side: with the neon gone the room went dark before the rattle (Play check
		-- 11-16). It goes with the stage copy.
		local fill = Instance.new("Part")
		fill.Name = "CutsceneFill"
		fill.Anchored = true
		fill.CanCollide = false
		fill.CanQuery = false
		fill.Transparency = 1
		fill.Size = Vector3.new(0.2, 0.2, 0.2)
		local lx = if outcome.locker == "gleam" then -6.5 else 6.5
		fill.CFrame = LockerViewModel.STAGE_ORIGIN * CFrame.new(lx - 1, 9, -3)
		local fillLight = Instance.new("PointLight")
		fillLight.Color = Color3.fromRGB(255, 236, 210)
		fillLight.Brightness = 0.8
		fillLight.Range = 18
		fillLight.Shadows = false
		fillLight.Parent = fill
		fill.Parent = stage
	end
	local leakUpdate, leakCleanup = buildLeak(lockerModel, fx)
	local white = Color3.new(1, 1, 1)
	local keyClicked = false
	local lastBeat: LockerViewModel.CutsceneBeat? = nil
	local rattle: SoundServiceClient.SoundHandle? = nil

	-- The beats' sounds, each once, as its beat starts.
	local function playBeat(pose: LockerViewModel.CutscenePose)
		if not keyClicked and pose.keyRollDeg > 0 then
			keyClicked = true
			SoundServiceClient:playOneShot("lockerKey")
		end
		if pose.beat == lastBeat then
			return
		end
		lastBeat = pose.beat
		if pose.beat == "rattle" then
			rattle = SoundServiceClient:play("lockerRattle", { volumeScale = 0.6 + 0.12 * fx.rattleDeg })
		elseif pose.beat == "burst_open" then
			local handle = rattle
			if handle ~= nil then
				handle:stop(0.1)
				rattle = nil
			end
			SoundServiceClient:playOneShot("lockerBurst")
			for _, id in fx.chime do
				SoundServiceClient:playOneShot(id)
			end
		end
	end

	local function applyAt(alpha: number)
		local pose = LockerViewModel.cutscenePose(outcome.locker, alpha, outcome.rarity)
		playBeat(pose)
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
		local update = leakUpdate
		if update ~= nil then
			-- The seams go dark once the door is open (the burst's own light takes over).
			update(
				if pose.glow then 0 else pose.leak,
				os.clock() - startedAt,
				white:Lerp(rarityShade.base, pose.leakTint)
			)
		end
		if pose.glow ~= glowActive then
			glowActive = pose.glow
			-- The rarity's full colour, not its pale tint: the pale one bloomed to white (Play check 11-16).
			setBurstGlow(lockerModel, glowActive, rarityShade.base, fx)
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
		local handle = rattle
		if handle ~= nil then
			handle:stop(0.1)
			rattle = nil
		end
		if leakCleanup ~= nil then
			leakCleanup()
		end
		if actor ~= nil and actorLive then
			-- Frees its live preview slot at once.
			EmployeePreviewSystem.release(actor)
		end
		if ownedStage then
			stage:Destroy()
		else
			setDoorAngle(lockerModel, 0)
			setBurstGlow(lockerModel, false, rarityShade.hi, fx)
			if keyModel ~= nil and keyModel:IsA("Model") then
				keyModel:PivotTo(CFrame.new(0, -100, 0))
			end
			if actor ~= nil and not actorLive then
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
