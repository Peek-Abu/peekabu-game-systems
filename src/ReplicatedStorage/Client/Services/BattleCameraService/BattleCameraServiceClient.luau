--!strict
--[=[
	Battle camera + input lock. Locks movement, takes over camera (Scriptable),
	provides shake / tween / focus / cinematic primitives.
	@class BattleCameraServiceClient
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local BattleSignals = require(ReplicatedStorage.Client.Signals.BattleSignals)

local log = Logger.new("BattleCameraService")

local BattleCameraServiceClient = {}
BattleCameraServiceClient.dependencies = { "BattleServiceClient" } :: { string }

local janitor = Janitor.new()
local battleJanitor = Janitor.new()

-- State
local _state = "None" -- "None" | "Overview" | "Focus" | "Cinematic"
local _overviewCFrame: CFrame = CFrame.new()
local _overviewFOV: number = 55
local _savedWalkSpeed: number = 16
local _savedJumpHeight: number = 7.2
local _savedCameraType: Enum.CameraType = Enum.CameraType.Custom
local _savedFOV: number = 70
local _inBattle: boolean = false
local _shakeOffset: CFrame = CFrame.new()
local _shakeActive: boolean = false
local _activeTween: Tween? = nil

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function getCamera(): Camera return workspace.CurrentCamera end

local function getCharacter(): Model?
	return Players.LocalPlayer and Players.LocalPlayer.Character
end

local function getHumanoid(): Humanoid?
	local c = getCharacter()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function resolvePosition(target: Vector3 | BasePart | Model): Vector3
	if typeof(target) == "Vector3" then return target end
	if typeof(target) == "Instance" then
		if target:IsA("Model") then
			local root = (target :: Model):FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then return root.Position end
			return (target :: Model):GetPivot().Position
		elseif target:IsA("BasePart") then
			return (target :: BasePart).Position
		end
	end
	return Vector3.zero
end

local function cancelActiveTween()
	if _activeTween then _activeTween:Cancel(); _activeTween = nil end
end

-- ── Movement Lock ────────────────────────────────────────────────────────────

local _playerModule: any = nil
local function getPlayerModule()
	if _playerModule then return _playerModule end
	local ps = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	if ps then
		pcall(function() _playerModule = require(ps:WaitForChild("PlayerModule", 2)) end)
	end
	return _playerModule
end

local function lockMovement()
	local hum = getHumanoid()
	if hum then
		_savedWalkSpeed = hum.WalkSpeed
		_savedJumpHeight = hum.JumpHeight
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
	end
	local pm = getPlayerModule()
	if pm then pcall(function() pm:GetControls():Disable() end) end
end

local function unlockMovement()
	local hum = getHumanoid()
	if hum then
		hum.WalkSpeed = _savedWalkSpeed
		hum.JumpHeight = _savedJumpHeight
	end
	local pm = getPlayerModule()
	if pm then pcall(function() pm:GetControls():Enable() end) end
end

-- ── Camera Primitives ────────────────────────────────────────────────────────

function BattleCameraServiceClient:tweenTo(targetCFrame: CFrame, duration: number?, easingStyle: Enum.EasingStyle?): Tween
	cancelActiveTween()
	local tween = TweenService:Create(getCamera(),
		TweenInfo.new(duration or 0.5, easingStyle or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = targetCFrame })
	_activeTween = tween
	tween:Play()
	tween.Completed:Once(function() if _activeTween == tween then _activeTween = nil end end)
	return tween
end

function BattleCameraServiceClient:tweenFOV(fov: number, duration: number?): Tween
	local tween = TweenService:Create(getCamera(),
		TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = fov })
	tween:Play()
	return tween
end

function BattleCameraServiceClient:shake(params: { intensity: number?, duration: number?, frequency: number?, decay: boolean? }?)
	local p = params or {}
	local intensity = p.intensity or 0.5
	local duration = p.duration or 0.3
	local frequency = p.frequency or 30
	local decay = if p.decay ~= nil then p.decay else true
	_shakeActive = true
	task.spawn(function()
		local elapsed, interval = 0, 1 / frequency
		while elapsed < duration and _inBattle do
			local falloff = if decay then (1 - elapsed / duration) else 1
			local m = intensity * falloff
			_shakeOffset = CFrame.new(
				(math.random() - 0.5) * m * 2,
				(math.random() - 0.5) * m * 2,
				(math.random() - 0.5) * m * 0.5)
			task.wait(interval)
			elapsed += interval
		end
		_shakeOffset = CFrame.new()
		_shakeActive = false
	end)
end

function BattleCameraServiceClient:focusOn(target: Vector3 | BasePart | Model, distance: number?, elevation: number?, duration: number?)
	local pos = resolvePosition(target)
	local dist = distance or 8
	local elev = elevation or 3
	_state = "Focus"
	return self:tweenTo(CFrame.lookAt(pos + Vector3.new(0, elev, dist), pos), duration or 0.4)
end

function BattleCameraServiceClient:setCinematic(cf: CFrame, fov: number?, duration: number?): Tween
	_state = "Cinematic"
	if fov then self:tweenFOV(fov, duration or 0.6) end
	return self:tweenTo(cf, duration or 0.6, Enum.EasingStyle.Cubic)
end

function BattleCameraServiceClient:returnToOverview(duration: number?): Tween
	_state = "Overview"
	self:tweenFOV(_overviewFOV, duration or 0.5)
	return self:tweenTo(_overviewCFrame, duration or 0.5, Enum.EasingStyle.Sine)
end

-- ── Animation Event Hooks ────────────────────────────────────────────────────
-- Bind animation track keyframe markers to camera effects. Returns cleanup fn.
-- Usage: local unbind = svc:bindToAnimationTrack(track, { CameraShake = fn, ... })

function BattleCameraServiceClient:bindToAnimationTrack(
	track: AnimationTrack,
	bindings: { [string]: (self: typeof(BattleCameraServiceClient)) -> () }
): () -> ()
	local conns: { RBXScriptConnection } = {}
	for name, cb in bindings do
		table.insert(conns, track:GetMarkerReachedSignal(name):Connect(function() cb(self) end))
	end
	return function() for _, c in conns do c:Disconnect() end end
end

-- ── Overview Setup (JRPG angle) ──────────────────────────────────────────────
-- Classic turn-based perspective: allies bottom-left (close), enemies upper-right (far).
-- Camera behind + left of ally, elevated, looking diagonally across the battlefield.

function BattleCameraServiceClient:setupOverview(allyPos: Vector3, enemyPos: Vector3, instant: boolean?)
	local battleDir = (enemyPos - allyPos)
	local battleDist = battleDir.Magnitude
	battleDir = if battleDist > 0.1 then battleDir.Unit else Vector3.new(0, 0, -1)

	-- "Left" from the ally's perspective (perpendicular to battle axis, horizontal)
	local leftDir = battleDir:Cross(Vector3.new(0, 1, 0)).Unit

	-- Camera position: behind ally, shifted left, elevated
	local behindDist = math.clamp(battleDist * 0.65, 6, 18)
	local lateralShift = math.clamp(battleDist * 0.5, 4, 12)
	local elevation = math.clamp(battleDist * 0.2, 4, 12)

	local cameraPos = allyPos
		- battleDir * behindDist
		+ leftDir * lateralShift
		+ Vector3.new(0, elevation, 0)

	-- Look past center toward the enemy side so enemies appear right-of-center
	local center = (allyPos + enemyPos) / 2
	local lookTarget = center + battleDir * (battleDist * 0.15) + Vector3.new(0, 1.5, 0)

	_overviewCFrame = CFrame.lookAt(cameraPos, lookTarget)
	_overviewFOV = 55
	_state = "Overview"

	local camera = getCamera()
	if instant then
		camera.CFrame = _overviewCFrame
		camera.FieldOfView = _overviewFOV
	else
		self:tweenTo(_overviewCFrame, 0.8, Enum.EasingStyle.Sine)
		self:tweenFOV(_overviewFOV, 0.8)
	end
end

-- ── Enter / Exit Battle ──────────────────────────────────────────────────────

function BattleCameraServiceClient:enterBattle(allyPos: Vector3?, enemyPos: Vector3?)
	if _inBattle then return end
	_inBattle = true

	local camera = getCamera()
	_savedCameraType = camera.CameraType
	_savedFOV = camera.FieldOfView

	lockMovement()
	camera.CameraType = Enum.CameraType.Scriptable

	-- Resolve ally position from player character if not provided
	if not allyPos then
		local c = getCharacter()
		if c then
			local root = c:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then allyPos = root.Position end
		end
	end
	allyPos = allyPos or Vector3.new(0, 3, 0)
	enemyPos = enemyPos or allyPos + Vector3.new(0, 0, -15)

	self:setupOverview(allyPos, enemyPos, true)

	-- Additive shake overlay each frame
	battleJanitor:Add(RunService.RenderStepped:Connect(function()
		if _inBattle and _shakeActive then
			camera.CFrame = camera.CFrame * _shakeOffset
		end
	end))

	log:info("Entered battle camera mode")
end

function BattleCameraServiceClient:exitBattle()
	if not _inBattle then return end
	_inBattle = false
	_state = "None"
	cancelActiveTween()
	_shakeOffset = CFrame.new()
	_shakeActive = false
	battleJanitor:Cleanup()

	local camera = getCamera()
	camera.CameraType = _savedCameraType
	camera.FieldOfView = _savedFOV
	unlockMovement()
	log:info("Exited battle camera mode")
end

-- ── Queries ──────────────────────────────────────────────────────────────────

function BattleCameraServiceClient:isInBattle(): boolean return _inBattle end
function BattleCameraServiceClient:getCameraState(): string return _state end
function BattleCameraServiceClient:setCameraState(state: string) _state = state end
function BattleCameraServiceClient:getState(): { [string]: any }
	return { cameraState = _state, inBattle = _inBattle, overviewCFrame = _overviewCFrame }
end

-- ── Service Lifecycle ────────────────────────────────────────────────────────

function BattleCameraServiceClient.init(self: any)
	janitor:Add(BattleSignals.BattleStarted:Connect(function(data)
		local allyPos, enemyPos: Vector3? = nil, nil

		-- Resolve ally position from player character
		local c = getCharacter()
		if c then
			local root = c:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then allyPos = root.Position end
		end

		-- Resolve enemy position: try BattleServiceClient model map first, then workspace search
		if data.enemies and #data.enemies > 0 then
			-- Try BattleServiceClient model map (most reliable)
			local battleSvc = nil
			pcall(function()
				local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)
				battleSvc = ServiceController:getService("BattleServiceClient")
			end)
			if battleSvc then
				local allyCount = data.allies and #data.allies or 0
				local enemyCount = #data.enemies
                local enemyPosSum = Vector3.new(0, 0, 0)
				local validEnemies = 0
				for i = 1, enemyCount do
					local enemyIndex = allyCount + i
					local enemyModel = battleSvc:getModelForIndex(enemyIndex)
					if enemyModel and enemyModel:IsA("Model") then
						local root = enemyModel:FindFirstChild("HumanoidRootPart")
						if root and root:IsA("BasePart") then
							enemyPosSum = enemyPosSum + root.Position
							validEnemies = validEnemies + 1
						end
					end
				end
				if validEnemies > 0 then
					enemyPos = enemyPosSum / validEnemies
				end
			end
		end

		self:enterBattle(allyPos, enemyPos)
	end), "Disconnect")

	janitor:Add(BattleSignals.BattleEnded:Connect(function(_data)
		task.delay(2.5, function() self:exitBattle() end)
	end), "Disconnect")
end

function BattleCameraServiceClient.stop(_self: any)
	battleJanitor:Cleanup()
	janitor:Cleanup()
	if _inBattle then
		_inBattle = false; _state = "None"
		getCamera().CameraType = _savedCameraType
		getCamera().FieldOfView = _savedFOV
		unlockMovement()
	end
end

return BattleCameraServiceClient
