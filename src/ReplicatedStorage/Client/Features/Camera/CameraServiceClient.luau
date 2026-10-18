--!strict
--[=[
	CameraServiceClient: the one owner of the local camera (design:
	docs/superpowers/specs/2026-10-09-camera-design.md).

	Systems push MODES (`pushMode` â†’ token; the highest priority wins, the latest wins ties) and add
	EFFECTS (`addTrauma`, `kickFov`, `setFovOffset`, `addModifier`). Every frame, just after the engine camera updates,
	it applies the top mode, then layers the shake, the custom modifiers and the FOV on top. It owns
	`FieldOfView` outright (written absolutely each frame: the mode's FOV or the base FOV, plus kicks).

	It also owns the UI's `cameraState` suppression seam: while a scene requests it, the view holds still.

	Spec-exempt shell (Camera, RunService, Player); the maths and stacks are specced beside it.

	@class CameraServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraClient = ReplicatedStorage.Client.Features.Camera
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CameraTypes = require(CameraClient.Data.CameraTypes)
local CameraConstants = require(CameraClient.Data.CameraConstants)
local CameraMotionFormulas = require(CameraClient.Utils.CameraMotionFormulas)
local CameraModeTracker = require(CameraClient.State.CameraModeTracker)
local CameraEffectTracker = require(CameraClient.State.CameraEffectTracker)
local CameraOcclusionFormulas = require(CameraClient.Utils.CameraOcclusionFormulas)
local CameraOcclusionSystem = require(CameraClient.Systems.CameraOcclusionSystem)
local UISuppression = require(ReplicatedStorage.Client.UI.Suppression.UISuppression)

type ModeDef = CameraTypes.ModeDef
type Modifier = CameraTypes.Modifier

-- The priority the UI's held view uses: above ordinary gameplay modes, below anything a game marks
-- as more important (a death cam, a forced cutscene).
local UI_HOLD_PRIORITY = 100

local SHAKE_CONFIG: CameraMotionFormulas.ShakeConfig = {
	maxPitch = CameraConstants.SHAKE_MAX_PITCH,
	maxYaw = CameraConstants.SHAKE_MAX_YAW,
	maxRoll = CameraConstants.SHAKE_MAX_ROLL,
	frequency = CameraConstants.SHAKE_FREQUENCY,
}

local previousMaxZoom: number? = nil
local previousMinZoom: number? = nil

local log = Logger.new("CameraServiceClient")

local modes = CameraModeTracker.new()
local effects = CameraEffectTracker.new(CameraConstants.TRAUMA_DECAY)
local modifiers: { Modifier } = {}

local baseFov = 70
local clock = 0
-- The token of the mode whose engine settings are currently applied (0 = none / the bare engine).
local appliedToken = 0
-- What applying a `default` mode changed, so leaving it restores exactly that.
local savedCameraMode: Enum.CameraMode? = nil
local changedSubject = false
-- The smoothed CFrame a `follow` mode is easing.
local followCFrame: CFrame? = nil
local modifierErrors = 0
-- Accessibility: scales every shake (Settings writes it through setShakeScale).
local shakeScale = 1
-- Held FOV offsets by owner (setFovOffset): unlike a kick they stay until their owner changes or clears them.
local fovOffsets: { [string]: number? } = {}
-- The occlusion pass's current limit (studs from the focus) while it holds the camera in; nil = not holding.
local occlusionLimit: number? = nil
local occlusionPulls = 0

local function heldFov(): number
	local total = 0
	for _, degrees in fovOffsets do
		total += degrees or 0
	end
	return total
end

local function currentCamera(): Camera?
	return Workspace.CurrentCamera
end

local function localHumanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Undoes whatever the previously applied mode changed on the engine.
local function restoreEngine(camera: Camera)
	camera.CameraType = Enum.CameraType.Custom
	local mode = savedCameraMode
	if mode ~= nil then
		Players.LocalPlayer.CameraMode = mode
		savedCameraMode = nil
	end
	if changedSubject then
		local humanoid = localHumanoid()
		if humanoid ~= nil then
			camera.CameraSubject = humanoid
		end
		changedSubject = false
	end
	followCFrame = nil
end

-- What the occlusion sweep looks through: every player's character (the engine's Poppercam does the same).
local function characters(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(list, character)
		end
	end
	return list
end

local function subjectPart(camera: Camera): BasePart?
	local subject = camera.CameraSubject
	if subject ~= nil and subject:IsA("Humanoid") then
		return subject.RootPart
	elseif subject ~= nil and subject:IsA("BasePart") then
		return subject
	end
	return nil
end

-- Our wall check over the engine's (CameraOcclusionSystem): pulls the engine's third-person camera in front of any
-- wall, proxy or prop between it and its focus; snaps in, eases back out (CameraOcclusionFormulas).
local function occlude(camera: Camera, dt: number)
	local focus = camera.Focus.Position
	local position = camera.CFrame.Position
	local engine = (position - focus).Magnitude
	if engine < CameraConstants.OCCLUSION_MIN_DISTANCE then
		occlusionLimit = nil
		return
	end
	local clear = CameraOcclusionSystem.clearance(focus, position, characters(), subjectPart(camera))
	local limit = CameraOcclusionFormulas.limit(occlusionLimit, clear, dt, CameraConstants.OCCLUSION_RELEASE)
	if not CameraOcclusionFormulas.applies(engine, limit) then
		occlusionLimit = nil
		return
	end
	occlusionLimit = limit
	occlusionPulls += 1
	camera.CFrame += (position - focus).Unit * (limit - engine)
end

-- Applies a newly-topped mode's engine settings (once, when the top changes).
local function applyEngine(camera: Camera, def: ModeDef?)
	restoreEngine(camera)
	if def == nil then
		return
	end
	if def.kind == "default" then
		if def.firstPerson == true then
			savedCameraMode = Players.LocalPlayer.CameraMode
			Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
		end
		local subject = def.subject
		if subject ~= nil then
			camera.CameraSubject = subject
			changedSubject = true
		end
	else
		camera.CameraType = Enum.CameraType.Scriptable
		followCFrame = camera.CFrame
	end
end

-- The mode's CFrame and FOV this frame. Nil CFrame = leave the engine's.
local function evaluate(camera: Camera, def: ModeDef?, dt: number): (CFrame?, number?)
	if def == nil then
		return nil, nil
	end
	if def.kind == "default" then
		return nil, def.fov
	elseif def.kind == "fixed" then
		return def.cframe, def.fov
	elseif def.kind == "follow" then
		local target = def.subject.CFrame * def.offset
		if def.lookAt == true then
			target = CFrame.lookAt(target.Position, def.subject.Position)
		end
		local sharpness = def.sharpness or CameraConstants.FOLLOW_SHARPNESS
		local from = followCFrame or camera.CFrame
		local nextCFrame = from:Lerp(target, CameraMotionFormulas.smoothingAlpha(sharpness, dt))
		followCFrame = nextCFrame
		return nextCFrame, def.fov
	else
		return def.update(dt)
	end
end

local function step(dt: number)
	local camera = currentCamera()
	if camera == nil then
		return
	end
	clock += dt
	local entry = modes:top()
	local token = if entry ~= nil then entry.token else 0
	local def = if entry ~= nil then entry.def else nil
	if token ~= appliedToken then
		applyEngine(camera, def)
		appliedToken = token
	end

	local modeCFrame, modeFov = evaluate(camera, def, dt)
	if modeCFrame ~= nil then
		camera.CFrame = modeCFrame
	end
	-- Only while the engine drives a third-person view: an authored shot (fixed, follow, custom) frames itself.
	local engineView = (def == nil or (def.kind == "default" and def.firstPerson ~= true))
		and camera.CameraType == Enum.CameraType.Custom
	if engineView then
		occlude(camera, dt)
	else
		occlusionLimit = nil
	end

	effects:step(dt)
	local pitch, yaw, roll = CameraMotionFormulas.shakeAngles(effects:trauma(), clock, SHAKE_CONFIG)
	local offset = CFrame.Angles(pitch * shakeScale, yaw * shakeScale, roll * shakeScale)
	for _, modifier in table.clone(modifiers) do
		local ok, result = pcall(modifier, dt)
		if ok then
			offset *= result
		else
			modifierErrors += 1
			log:error(`camera modifier failed: {tostring(result)}`)
		end
	end
	if offset ~= CFrame.identity then
		camera.CFrame *= offset
	end
	camera.FieldOfView = (modeFov or baseFov) + effects:fovOffset() + heldFov()
end

export type CameraServiceClient = {
	dependencies: { string },
	start: (self: CameraServiceClient) -> (),
	stop: (self: CameraServiceClient) -> (),
	getState: (self: CameraServiceClient) -> { [string]: any },

	pushMode: (self: CameraServiceClient, def: ModeDef, priority: number?) -> number,
	removeMode: (self: CameraServiceClient, token: number) -> boolean,
	addTrauma: (self: CameraServiceClient, amount: number) -> (),
	kickFov: (self: CameraServiceClient, amount: number, duration: number) -> (),
	addModifier: (self: CameraServiceClient, modifier: Modifier) -> () -> (),
	setShakeScale: (self: CameraServiceClient, scale: number) -> (),
	setFovOffset: (self: CameraServiceClient, owner: string, degrees: number) -> (),
}

local connections: { RBXScriptConnection } = {}

local CameraServiceClient: CameraServiceClient = {
	dependencies = {},

	--[=[
		Captures the base FOV, binds the render step just after the engine camera, re-applies a
		spectate subject after a respawn (the engine resets CameraSubject to the new Humanoid), and takes
		over the UI's `cameraState` seam.
	]=]
	start = function(self)
		local player = Players.LocalPlayer
		previousMaxZoom = player.CameraMaxZoomDistance
		previousMinZoom = player.CameraMinZoomDistance
		player.CameraMinZoomDistance = CameraConstants.MIN_ZOOM_DISTANCE
		player.CameraMaxZoomDistance = CameraConstants.MAX_ZOOM_DISTANCE
		local camera = currentCamera()
		if camera ~= nil then
			baseFov = camera.FieldOfView
		end
		RunService:BindToRenderStep(
			CameraConstants.RENDER_STEP_NAME,
			Enum.RenderPriority.Camera.Value + CameraConstants.RENDER_PRIORITY_OFFSET,
			step
		)
		table.insert(
			connections,
			Players.LocalPlayer.CharacterAdded:Connect(function()
				-- Force the top mode to re-apply on the next frame; `changedSubject` is stale now.
				changedSubject = false
				appliedToken = -1
			end)
		)

		local holdToken: number? = nil
		UISuppression.registerHandler("cameraState", {
			engage = function()
				local held = currentCamera()
				local cframe = if held ~= nil then held.CFrame else CFrame.identity
				holdToken = self:pushMode({ kind = "fixed", cframe = cframe }, UI_HOLD_PRIORITY)
			end,
			disengage = function()
				local token = holdToken
				if token ~= nil then
					self:removeMode(token)
					holdToken = nil
				end
			end,
		})
	end,

	stop = function(_self)
		local player = Players.LocalPlayer
		if previousMaxZoom ~= nil then
			player.CameraMaxZoomDistance = previousMaxZoom
		end
		if previousMinZoom ~= nil then
			player.CameraMinZoomDistance = previousMinZoom
		end
		previousMaxZoom = nil
		previousMinZoom = nil
		RunService:UnbindFromRenderStep(CameraConstants.RENDER_STEP_NAME)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		local camera = currentCamera()
		if camera ~= nil then
			restoreEngine(camera)
			camera.FieldOfView = baseFov
		end
		appliedToken = 0
		occlusionLimit = nil
		effects:reset()
		table.clear(fovOffsets)
	end,

	--[=[
		Pushes a camera mode; returns the token that removes it. Higher `priority` wins (default 0);
		the latest push wins ties.
	]=]
	pushMode = function(_self, def, priority)
		return modes:push(def, priority or 0)
	end,

	removeMode = function(_self, token)
		return modes:remove(token)
	end,

	--[=[
		Adds shake trauma (0..1; the total clamps at 1 and decays over time).
	]=]
	addTrauma = function(_self, amount)
		effects:addTrauma(amount)
	end,

	--[=[
		Kicks the FOV by `amount` degrees, easing back over `duration` seconds. Kicks sum.
	]=]
	kickFov = function(_self, amount, duration)
		effects:kickFov(amount, duration)
	end,

	--[=[
		Adds a per-frame CFrame offset (head bob, sway, lean). Returns a function that removes it.
	]=]
	addModifier = function(_self, modifier)
		table.insert(modifiers, modifier)
		return function()
			local index = table.find(modifiers, modifier)
			if index ~= nil then
				table.remove(modifiers, index)
			end
		end
	end,

	--[=[
		Scales every shake (0 = off, 1 = full): the player's accessibility setting.
	]=]
	setShakeScale = function(_self, scale)
		shakeScale = math.clamp(scale, 0, 1)
	end,

	--[=[
		Holds an FOV offset of `degrees` for `owner` (0 clears it), added on top of the mode's FOV and the kicks until
		the owner changes it. Offsets from different owners sum.
	]=]
	setFovOffset = function(_self, owner, degrees)
		fovOffsets[owner] = if degrees ~= 0 then degrees else nil
	end,

	getState = function(_self)
		local top = modes:top()
		return {
			mode = if top ~= nil then top.def.kind else "engine",
			modes = modes:count(),
			trauma = effects:trauma(),
			shakeScale = shakeScale,
			fovHeld = heldFov(),
			fovKicks = effects:activeKicks(),
			modifiers = #modifiers,
			modifierErrors = modifierErrors,
			occlusionLimit = occlusionLimit or 0,
			occlusionPulls = occlusionPulls,
		}
	end,
}

return CameraServiceClient
