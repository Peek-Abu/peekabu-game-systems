--!strict
--[=[
	TrainingCoachSystem: the coach at the hub's Training pad on this client (owner 11-11: an NPC with a purpose; it
	replaces the floating "New here?" sign). While this player still needs training, Pippa stands beside each Training
	pad on the side facing the hub. She is alive, not a statue (owner 11-11): the stock idle loops under her, she waves
	when the player walks up and every few seconds on her own, and her head follows the player
	(TrainingCoachRules). Every clip is generic (the stock idle and the wave made for every employee), never a
	per-character animation. She carries no billboard: what she says is the on-screen coach card (TrainingHubSystem's
	spotlight step, with the edge arrow and the gold floor trail leading to the pad), because text floating in the
	world swings around as the camera moves (owner 11-11). Once they have trained she is gone for them (the pad keeps
	its plain TRAINING tag, so anyone can play it again). Built locally (a clone of the character, anchored and inert),
	so nothing replicates and nobody else sees another player's coach.

	Spec-exempt shell (Instances, the Animator, the neck joint); the decisions are the specced TrainingRules.isNew and
	TrainingCoachRules.

	@class TrainingCoachSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingCoachRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingCoachRules)
local TrainingAssets = require(ReplicatedStorage.Client.Features.Training.Data.TrainingAssets)
local EmployeeNpcUtils = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeNpcUtils)

local COACH = TrainingConstants.HUB_COACH
-- Seconds the clips blend into each other.
local FADE = 0.25

type Coach = {
	model: Model,
	wave: AnimationTrack?,
	neck: Motor6D?,
	-- The neck's rest C0, the head's current turn (radians), when she next waves on her own (os.clock), and whether
	-- the player was near last frame (she waves when they walk up, not while they stand there).
	rest: CFrame,
	yaw: number,
	pitch: number,
	due: number,
	near: boolean,
	connection: RBXScriptConnection?,
}

-- The coach built beside each pad (this client only).
local coaches: { [BasePart]: Coach } = {}
local random = Random.new()

local function load(animator: Animator, id: string, looped: boolean, priority: Enum.AnimationPriority): AnimationTrack
	local clip = Instance.new("Animation")
	clip.AnimationId = id
	local track = animator:LoadAnimation(clip)
	track.Looped = looped
	track.Priority = priority
	return track
end

-- Turns the head toward the local player and waves when it is time.
local function step(coach: Coach, dt: number)
	local model = coach.model
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if root == nil or not root:IsA("BasePart") or head == nil or not head:IsA("BasePart") then
		return
	end
	local character = Players.LocalPlayer.Character
	local distance: number? = nil
	local yawTarget, pitchTarget = 0, 0
	if character ~= nil then
		local target = character:GetPivot().Position + Vector3.new(0, 1, 0)
		distance = (target - root.Position).Magnitude
		yawTarget, pitchTarget = TrainingCoachRules.headTurn(root.CFrame:VectorToObjectSpace(target - head.Position))
	end
	coach.yaw = TrainingCoachRules.ease(coach.yaw, yawTarget, dt)
	coach.pitch = TrainingCoachRules.ease(coach.pitch, pitchTarget, dt)
	local neck = coach.neck
	if neck ~= nil then
		-- A turn in the torso's space on top of whatever the clip does to the neck.
		local rest = coach.rest
		neck.C0 = CFrame.new(rest.Position)
			* CFrame.Angles(0, coach.yaw, 0)
			* CFrame.Angles(coach.pitch, 0, 0)
			* rest.Rotation
	end
	local now = os.clock()
	local wave = coach.wave
	if wave ~= nil and not wave.IsPlaying and TrainingCoachRules.wavesNow(distance, coach.near, now, coach.due) then
		wave:Play(FADE, 1, 1)
		coach.due = TrainingCoachRules.nextWave(now, random:NextNumber())
	end
	coach.near = distance ~= nil and distance <= COACH.WAVE.RADIUS
end

local function build(pad: BasePart): Coach?
	local copy = EmployeeNpcUtils.clone(COACH.EMPLOYEE)
	if copy == nil then
		return nil
	end
	local model: Model = copy
	model.Name = "TrainingCoach"
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	root.Anchored = true
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
		end
	end
	-- Beside the pad on the side the hub is on (COACH.SIDE in the pad's space), facing out of the bay.
	local base = pad.CFrame * CFrame.new(COACH.SIDE)
	local feet = Vector3.new(base.Position.X, pad.Position.Y - pad.Size.Y / 2, base.Position.Z)
	local facing = pad.CFrame:VectorToWorldSpace(COACH.FACING)
	model:PivotTo(CFrame.lookAt(feet, feet + Vector3.new(facing.X, 0, facing.Z)))
	local frame, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, feet.Y - (frame.Position.Y - size.Y / 2), 0))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = humanoid or model
		animator = made
	end
	local head = model:FindFirstChild("Head")
	local neck = if head ~= nil then head:FindFirstChild("Neck") else nil
	local joint = if neck ~= nil and neck:IsA("Motor6D") then neck else nil
	model.Parent = Workspace
	local coach: Coach = {
		model = model,
		wave = nil,
		neck = joint,
		rest = if joint ~= nil then joint.C0 else CFrame.identity,
		yaw = 0,
		pitch = 0,
		due = TrainingCoachRules.nextWave(os.clock(), random:NextNumber()),
		near = false,
		connection = nil,
	}
	if animator ~= nil then
		local idle = AnimationRegistry.get(COACH.IDLE)
		if idle ~= nil then
			load(animator, idle.assetId, true, Enum.AnimationPriority.Idle):Play(0, 1, 1)
		end
		coach.wave = load(animator, TrainingAssets.COACH_WAVE, false, Enum.AnimationPriority.Action)
	end
	coach.connection = RunService.RenderStepped:Connect(function(dt: number)
		step(coach, dt)
	end)
	return coach
end

local TrainingCoachSystem = {}

-- Shows (or removes) the coach at `pad` for a player who still needs training (`isNew`).
function TrainingCoachSystem.set(pad: BasePart, isNew: boolean)
	if not isNew then
		TrainingCoachSystem.remove(pad)
		return
	end
	if coaches[pad] == nil then
		local coach = build(pad)
		if coach ~= nil then
			coaches[pad] = coach
		end
	end
end

-- Takes the coach at `pad` away (the pad left, or the player trained).
function TrainingCoachSystem.remove(pad: BasePart)
	local coach = coaches[pad]
	if coach == nil then
		return
	end
	coaches[pad] = nil
	local connection = coach.connection
	if connection ~= nil then
		connection:Disconnect()
	end
	coach.model:Destroy()
end

-- Whether a coach stands at `pad`.
function TrainingCoachSystem.has(pad: BasePart): boolean
	return coaches[pad] ~= nil
end

return TrainingCoachSystem
