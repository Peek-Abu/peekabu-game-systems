--!strict
--[=[
	OccupantHeadTurnSystem: a freeze kind's owl head on this client (Bramble; the freeze variants note, variant B).
	Each frame, for every tagged Occupant rig whose kind has the head-turn twist, its head turns smoothly toward the crew
	member the server names in HEAD_TARGET_ATTRIBUTE (OccupantWatchSystem, OccupantHeadRules): a yaw on the Neck
	Motor6D's C0 about the torso's up axis, up to 180 degrees either way (owl-style), eased at HEAD_TURN_RATE. Target 0
	(nobody) eases it back to the front. Even while the body is frozen the head keeps turning.

	Visual only: the server owns whom it looks at. It writes C0, never Transform, so the clips and
	OccupantGestureSystem (which writes Transform) are left alone. Harlow's kind has no head-turn twist, so his neck is
	never touched. `stop` puts every neck back.

	`yawToward`, `ease` and `turned` are specced; the rest is a RunService/Motor6D shell.

	@class OccupantHeadTurnSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)

-- A rig's neck: the motor, its authored C0, and the yaw it shows now.
type Neck = { motor: Motor6D, base: CFrame, yaw: number }

local necks: { [Model]: Neck } = {}
local connection: RBXScriptConnection? = nil

local OccupantHeadTurnSystem = {}

--[=[
	The yaw (radians, -pi..pi; positive turns left) that faces `point` from `frame`'s forward (-Z), on the flat.
]=]
function OccupantHeadTurnSystem.yawToward(frame: CFrame, point: Vector3): number
	local offset = frame:PointToObjectSpace(point)
	if math.abs(offset.X) < 1e-6 and math.abs(offset.Z) < 1e-6 then
		return 0
	end
	return math.atan2(-offset.X, -offset.Z)
end

--[=[
	`current` eased toward `desired` over `deltaTime` at `rate` (exponential, never past it). No wrap-around: a target
	moving across its back swings the head back through the front, so it never turns past 180 degrees.
]=]
function OccupantHeadTurnSystem.ease(current: number, desired: number, deltaTime: number, rate: number): number
	local alpha = 1 - math.exp(-rate * math.max(0, deltaTime))
	return current + (desired - current) * alpha
end

--[=[
	The Neck's C0: its authored `base` turned `yaw` about the parent part's up axis, its position kept.
]=]
function OccupantHeadTurnSystem.turned(base: CFrame, yaw: number): CFrame
	return CFrame.new(base.Position) * CFrame.Angles(0, yaw, 0) * base.Rotation
end

local function turns(model: Model): boolean
	local kind = OccupantKindRegistry.get(OccupantKindRegistry.kindOf(model))
	local twist = if kind ~= nil then kind.freeze else nil
	return twist ~= nil and twist.headTurn
end

local function neckOf(model: Model): Neck?
	local known = necks[model]
	if known ~= nil and known.motor.Parent ~= nil then
		return known
	end
	local motor = model:FindFirstChild("Neck", true)
	if motor == nil or not motor:IsA("Motor6D") then
		return nil
	end
	local neck: Neck = { motor = motor, base = motor.C0, yaw = 0 }
	necks[model] = neck
	return neck
end

-- Where the named crew member is (their root), if they are here.
local function targetPosition(model: Model): Vector3?
	local value = model:GetAttribute(OccupantConstants.HEAD_TARGET_ATTRIBUTE)
	if type(value) ~= "number" or value == 0 then
		return nil
	end
	local player = Players:GetPlayerByUserId(value)
	local character = if player ~= nil then player.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function step(deltaTime: number)
	for model in necks do
		if model.Parent == nil then
			necks[model] = nil
		end
	end
	for _, instance in CollectionService:GetTagged(OccupantConstants.TAG) do
		if not instance:IsA("Model") or not turns(instance) then
			continue
		end
		local neck = neckOf(instance)
		local torso = if neck ~= nil then neck.motor.Part0 else nil
		if neck == nil or torso == nil then
			continue
		end
		local point = targetPosition(instance)
		local desired = if point ~= nil then OccupantHeadTurnSystem.yawToward(torso.CFrame, point) else 0
		neck.yaw = OccupantHeadTurnSystem.ease(neck.yaw, desired, deltaTime, OccupantConstants.HEAD_TURN_RATE)
		neck.motor.C0 = OccupantHeadTurnSystem.turned(neck.base, neck.yaw)
	end
end

function OccupantHeadTurnSystem.start()
	if connection ~= nil then
		return
	end
	connection = RunService.PreSimulation:Connect(step)
end

-- Stops turning and puts every neck back as it was authored.
function OccupantHeadTurnSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
		connection = nil
	end
	for _, neck in necks do
		if neck.motor.Parent ~= nil then
			neck.motor.C0 = neck.base
		end
	end
	table.clear(necks)
end

return OccupantHeadTurnSystem
