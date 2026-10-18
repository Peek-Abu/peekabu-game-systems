--!strict
--[=[
	CargoSlipSystem: slipping on the water jug's puddle (Cleanup Crew spec §4: "dropped = very loud splash +
	slippery puddle"). Every SLIP_CHECK the local character is tested against each puddle
	(CargoHandlingRules.slips); a slip stands the character down (PlatformStand) for SLIP_SECONDS and shoves it
	on along its motion. Client-side because the character's physics belong to its client; a slip only hinders
	the player who slips, so nothing authoritative rides on it.

	Spec-exempt shell (Humanoid, physics); the decision is the specced CargoHandlingRules.slips.

	@class CargoSlipSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoHandlingRules = require(ReplicatedStorage.Shared.Features.Cargo.Rules.CargoHandlingRules)

local connection: RBXScriptConnection? = nil
local lastSlipAt = -math.huge

local function slip(humanoid: Humanoid, root: BasePart, motion: Vector3)
	humanoid.PlatformStand = true
	if motion.Magnitude > 1e-3 then
		root:ApplyImpulse(motion.Unit * root.AssemblyMass * CargoConstants.SLIP_PUSH)
	end
	task.delay(CargoConstants.SLIP_SECONDS, function()
		if humanoid.Parent ~= nil and humanoid.Health > 0 then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function check(now: number)
	local character = Players.LocalPlayer.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local found = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or found == nil or not found:IsA("BasePart") then
		return
	end
	local root: BasePart = found
	if humanoid.PlatformStand or humanoid.Health <= 0 then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local motion = Vector3.new(velocity.X, 0, velocity.Z)
	for _, puddle in CollectionService:GetTagged(CargoConstants.PUDDLE_TAG) do
		if
			puddle:IsA("BasePart")
			and CargoHandlingRules.slips(
				puddle.CFrame:PointToObjectSpace(root.Position),
				puddle.Size,
				motion.Magnitude,
				now,
				lastSlipAt
			)
		then
			lastSlipAt = now
			slip(humanoid, root, motion)
			return
		end
	end
end

local CargoSlipSystem = {}

function CargoSlipSystem.start()
	if connection ~= nil then
		return
	end
	local elapsed = 0
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed >= CargoConstants.SLIP_CHECK then
			elapsed = 0
			check(os.clock())
		end
	end)
end

function CargoSlipSystem.stop()
	local current = connection
	if current ~= nil then
		current:Disconnect()
		connection = nil
	end
end

return CargoSlipSystem
