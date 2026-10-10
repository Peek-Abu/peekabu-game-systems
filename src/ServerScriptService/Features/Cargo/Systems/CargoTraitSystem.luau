--!strict
--[=[
	CargoTraitSystem: the handling traits that act over time (Cleanup Crew spec §4): a rattly item pulses a
	small noise every RATTLE_INTERVAL while carried, and the water jug leaves a slippery puddle where it hits
	the floor (players slip on it: CargoSlipSystem, client). Noise goes out through CargoServiceServer's
	`noiseMade` (passed in), like every Cargo noise; Noise relays it. Puddles live in the shift's container, so
	a reset clears them; each also expires after PUDDLE_SECONDS.

	Spec-exempt shell (Players, Carry, Instances); the trait decisions are the specced CargoHandlingRules.

	@class CargoTraitSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CarryTypes = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoHandlingRules = require(CargoShared.Rules.CargoHandlingRules)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local CargoSpawnSystem = require(ServerScriptService.Features.Cargo.Systems.CargoSpawnSystem)

export type Deps = {
	noiseMade: SignalTyped.Signal<Vector3, number, string>,
	spawner: CargoSpawnSystem.CargoSpawnSystem,
	container: () -> Instance?,
	ignore: (extra: Instance?) -> { Instance },
	isClaimed: (object: Instance) -> boolean,
}

export type CargoTraitSystem = {
	start: (self: CargoTraitSystem) -> (),
	stop: (self: CargoTraitSystem) -> (),
	puddles: (self: CargoTraitSystem) -> number,
}

local function defOf(object: Instance): CargoTypes.ItemDef?
	local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	return if type(kind) == "string" then CargoRegistry.get(kind) else nil
end

local CargoTraitSystem = {}

function CargoTraitSystem.new(deps: Deps): CargoTraitSystem
	local heartbeat: RBXScriptConnection? = nil
	local dropped: SignalTyped.Connection? = nil
	local made = 0

	-- One rattle pulse from everyone carrying a rattly item.
	local function rattle()
		for _, player in Players:GetPlayers() do
			local item = CarryServiceServer:getCarried(player)
			local def = if item ~= nil then defOf(item) else nil
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if def ~= nil and CargoHandlingRules.rattles(def) and root ~= nil and root:IsA("BasePart") then
				deps.noiseMade:Fire(root.Position, CargoConstants.RATTLE_NOISE, "rattle")
			end
		end
	end

	local function puddleAt(floor: CFrame, parent: Instance)
		local size = CargoConstants.PUDDLE_SIZE
		local part = Instance.new("Part")
		part.Name = "Puddle"
		part.Size = size
		part.CFrame = floor * CFrame.new(0, size.Y / 2, 0)
		part.Color = CargoConstants.PUDDLE_COLOR
		part.Material = Enum.Material.Glass
		part.Transparency = 0.35
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = parent
		CollectionService:AddTag(part, CargoConstants.PUDDLE_TAG)
		Debris:AddItem(part, CargoConstants.PUDDLE_SECONDS)
		made += 1
	end

	-- Carry's `dropped` (deferred). Items Cargo claimed first (banked, pocketed) never splash.
	local function onDropped(_player: Player, object: Instance, reason: CarryTypes.DropReason)
		local def = defOf(object)
		if def == nil or not CargoHandlingRules.leavesPuddle(def, reason) or deps.isClaimed(object) then
			return
		end
		local parent = deps.container()
		if parent == nil or parent.Parent == nil or not object:IsA("BasePart") or object.Parent == nil then
			return
		end
		puddleAt(deps.spawner:floorUnder(object.Position, deps.ignore(object)), parent)
	end

	local system: CargoTraitSystem = {
		start = function(_self)
			local elapsed = 0
			heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
				elapsed += deltaTime
				if elapsed >= CargoConstants.RATTLE_INTERVAL then
					elapsed = 0
					rattle()
				end
			end)
			dropped = CarryServiceServer.dropped:Connect(onDropped)
		end,

		stop = function(_self)
			local beat = heartbeat
			if beat ~= nil then
				beat:Disconnect()
				heartbeat = nil
			end
			local drops = dropped
			if drops ~= nil then
				drops:Disconnect()
				dropped = nil
			end
		end,

		puddles = function(_self)
			return made
		end,
	}
	return system
end

return CargoTraitSystem
