--!strict
--[=[
	DepotLoungeSystem: the break room's sleepy employee on this client (owner 11-11, ideas sheet #4: Cappy dozing on the
	sofa; DepotSpotConstants.LOUNGE, DepotLoungeRules). LOUNGE.EMPLOYEE (at player size, EmployeeNpcUtils) sits on the
	part tagged LOUNGE.TAG (a sofa cushion, facing its LookVector), dozing (DepotAssets.LOUNGE_DOZE, looped: breathing,
	nodding off and jerking awake). When the local player walks up he lifts his head and waves without getting up
	(DepotAssets.LOUNGE_WAVE, the upper body only), then dozes off again. Generic clips; local only (nothing
	replicates). Nothing shows until both clips are uploaded.

	Spec-exempt shell (Instances, the Animator); the decision is the specced DepotLoungeRules.wakes.

	@class DepotLoungeSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local DepotLoungeRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotLoungeRules)
local DepotAssets = require(ReplicatedStorage.Client.Features.Depot.Data.DepotAssets)
local EmployeeNpcUtils = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeNpcUtils)
local EmployeeFaceSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeeFaceSystem)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

local LOUNGE = DepotSpotConstants.LOUNGE
local FADE = 0.3
-- Seconds to wait for the doze clip to load before seating him on it.
local LOAD_TIMEOUT = 10

local function load(animator: Animator, id: string, looped: boolean, priority: Enum.AnimationPriority): AnimationTrack
	local clip = Instance.new("Animation")
	clip.AnimationId = id
	local track = animator:LoadAnimation(clip)
	track.Looped = looped
	track.Priority = priority
	return track
end

-- Seats `model` (already dozing) so his seat is on the spot's top: the lowest point of his pelvis on the cushion.
local function seat(model: Model, spot: BasePart)
	local pelvis = model:FindFirstChild("LowerTorso")
	if pelvis == nil or not pelvis:IsA("BasePart") then
		return
	end
	local top = spot.Position.Y + spot.Size.Y / 2
	local bottom = pelvis.Position.Y - pelvis.Size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, top - bottom, 0))
end

local function build(spot: BasePart): () -> ()
	local dozeId, waveId = DepotAssets.LOUNGE_DOZE, DepotAssets.LOUNGE_WAVE
	local copy = EmployeeNpcUtils.clone(LOUNGE.EMPLOYEE)
	if copy == nil or dozeId == nil or waveId == nil then
		if copy ~= nil then
			copy:Destroy()
		end
		return function() end
	end
	local model: Model = copy
	model.Name = "SofaSleeper"
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return function() end
	end
	root.Anchored = true
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
		end
	end
	local at = spot.Position
	local look = spot.CFrame.LookVector
	model:PivotTo(CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z)))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = humanoid or model
		animator = made
	end
	model.Parent = Workspace
	if animator == nil then
		model:Destroy()
		return function() end
	end
	local doze = load(animator, dozeId, true, Enum.AnimationPriority.Idle)
	local wave = load(animator, waveId, false, Enum.AnimationPriority.Action)
	doze:Play(0, 1, 1)
	-- Eyes closed while he dozes; his own face while he is awake to wave, closed again when the wave ends.
	local def = EmployeeRegistry.get(LOUNGE.EMPLOYEE)
	local function sleep()
		EmployeeFaceSystem.applyNamed(model, LOUNGE.SLEEP_FACE, true)
	end
	sleep()
	local dozedOff = wave.Stopped:Connect(sleep)
	local alive = true
	task.spawn(function()
		local waited = 0
		while doze.Length <= 0 and waited < LOAD_TIMEOUT do
			waited += RunService.RenderStepped:Wait()
		end
		RunService.RenderStepped:Wait()
		RunService.RenderStepped:Wait()
		if alive then
			seat(model, spot)
		end
	end)
	local near = false
	local lastAt: number? = nil
	local watcher = RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		if character == nil then
			near = false
			return
		end
		local distance = (character:GetPivot().Position - spot.Position).Magnitude
		local now = os.clock()
		if not wave.IsPlaying and DepotLoungeRules.wakes(distance, near, lastAt, now) then
			lastAt = now
			if def ~= nil then
				EmployeeFaceSystem.apply(model, def.defaultFace, true)
			end
			wave:Play(FADE, 1, 1)
		end
		near = distance <= LOUNGE.WAKE_RADIUS
	end)
	return function()
		alive = false
		watcher:Disconnect()
		dozedOff:Disconnect()
		model:Destroy()
	end
end

local DepotLoungeSystem = {}

-- Seats the sleeper on every lounge spot; returns the stopper.
function DepotLoungeSystem.start(): () -> ()
	return Observers.observeTag(LOUNGE.TAG, function(instance: Instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		return build(instance)
	end)
end

return DepotLoungeSystem
