--!strict
--[=[
	CargoTraitSystem: the handling traits that act over time (Cleanup Crew spec §4): a rattly item pulses a
	small noise every RATTLE_INTERVAL while carried, and the water jug leaves a slippery puddle where it hits
	the floor (players slip on it: CargoSlipSystem, client). Noise goes out through CargoServiceServer's
	`noiseMade` (passed in), like every Cargo noise; Noise relays it. Puddles live in the shift's container, so
	a reset clears them; each also expires after PUDDLE_SECONDS.
	Feel (M3): `sound` plays a Cargo sound where something happened, for everyone near it (CargoServiceServer calls it
	for each drop, which knows the item); rattles and searches are heard too, from `noiseMade`. Silent while an id
	is pending (CargoAssets; requiring it registers the uploaded sounds on the server).

	Spec-exempt shell (Players, Carry, Instances, Sound); the trait decisions are the specced CargoHandlingRules,
	the sound choices CargoFeedbackUtils.

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
local CargoAssets = require(CargoShared.Data.CargoAssets)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoHandlingRules = require(CargoShared.Rules.CargoHandlingRules)
local CargoFeedbackUtils = require(CargoShared.Utils.CargoFeedbackUtils)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local CargoSpawnSystem = require(ServerScriptService.Features.Cargo.Systems.CargoSpawnSystem)
local SoundServiceServer = require(ServerScriptService.Features.Sound.SoundServiceServer)

export type Deps = {
	noiseMade: SignalTyped.Signal<Vector3, number, string, { number }>,
	spawner: CargoSpawnSystem.CargoSpawnSystem,
	container: () -> Instance?,
	ignore: (extra: Instance?) -> { Instance },
	isClaimed: (object: Instance) -> boolean,
}

export type CargoTraitSystem = {
	start: (self: CargoTraitSystem) -> (),
	stop: (self: CargoTraitSystem) -> (),
	puddles: (self: CargoTraitSystem) -> number,
	sound: (self: CargoTraitSystem, position: Vector3, id: string) -> (),
}

-- A Cargo sound at a spot, for everyone near it; silent while its id is pending (CargoAssets).
local function soundAt(position: Vector3, id: string)
	if CargoAssets.SOUNDS[id] ~= nil and SoundRegistry.has(id) then
		SoundServiceServer:playAt(position, id, CargoConstants.SOUND_RADIUS)
	end
end

local function defOf(object: Instance): CargoTypes.ItemDef?
	local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	return if type(kind) == "string" then CargoRegistry.get(kind) else nil
end

local CargoTraitSystem = {}

function CargoTraitSystem.new(deps: Deps): CargoTraitSystem
	local heartbeat: RBXScriptConnection? = nil
	local dropped: SignalTyped.Connection? = nil
	local noises: SignalTyped.Connection? = nil
	local made = 0

	-- One rattle pulse from everyone carrying a rattly item.
	local function rattle()
		for _, player in Players:GetPlayers() do
			local item = CarryServiceServer:getCarried(player)
			local def = if item ~= nil then defOf(item) else nil
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if def ~= nil and CargoHandlingRules.rattles(def) and root ~= nil and root:IsA("BasePart") then
				deps.noiseMade:Fire(root.Position, CargoConstants.RATTLE_NOISE, "rattle", { player.UserId })
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
			-- Rattles and searches are heard as sounds too (drops are played by CargoServiceServer, which knows the item).
			noises = deps.noiseMade:Connect(function(position: Vector3, _radius: number, source: string)
				local id = CargoFeedbackUtils.noiseSound(source)
				if id ~= nil then
					soundAt(position, id)
				end
			end)
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
			local heard = noises
			if heard ~= nil then
				heard:Disconnect()
				noises = nil
			end
		end,

		puddles = function(_self)
			return made
		end,

		sound = function(_self, position, id)
			soundAt(position, id)
		end,
	}
	return system
end

return CargoTraitSystem
