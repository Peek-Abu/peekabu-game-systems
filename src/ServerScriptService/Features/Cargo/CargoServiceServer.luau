--!strict
--[=[
	CargoServiceServer: Cleanup Crew's cargo (spec §4 "Cargo and carrying", §6.4). Every catalog item is a
	Carry kind (weight by size, the bulky cart held far out) spawned by CargoSpawnSystem. On top of Carry:

	- Pockets (CargoPocketSystem): the `pocket` and `swap` packets; two tiny-only slots published as
	  `pocket1` / `pocket2`; scattered where their owner dies or leaves.
	- Handling (Carry's `dropped`, which SignalPlus delivers deferred): a fragile item loses a value tier per
	  impact; a recycling box spills into a pile (VacuumServiceServer:spawnPile); every drop fires `noiseMade`
	  (the M2 Noise seam).
	- Search: desks and lockers stocked per shift (`stockSearchable`); a short hold gives what was rolled.
	- Banking: the `cargo-load` interaction on the truck bed. Claim (CargoClaimTracker) → add (the game's
	  `onBanked` handler) → destroy, in one synchronous step, so two Loads never count one item twice.

	Spec-exempt shell (Instances, Players, ByteNet, signals); the rules are the specced CargoHandlingRules,
	CargoBankRules, CargoClaimTracker and CargoPocketTracker.

	@class CargoServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoServer = ServerScriptService.Features.Cargo
local CarryShared = ReplicatedStorage.Shared.Features.Carry
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CarryConstants = require(CarryShared.Data.CarryConstants)
local CarryRegistry = require(CarryShared.Data.CarryRegistry)
local CarryTypes = require(CarryShared.Data.CarryTypes)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoEvents = require(CargoShared.Net.CargoEvents)
local CargoBankRules = require(CargoShared.Rules.CargoBankRules)
local CargoHandlingRules = require(CargoShared.Rules.CargoHandlingRules)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local CargoClaimTracker = require(CargoServer.State.CargoClaimTracker)
local CargoPocketSystem = require(CargoServer.Systems.CargoPocketSystem)
local CargoSpawnSystem = require(CargoServer.Systems.CargoSpawnSystem)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

-- Registered at load, before any item spawns or any desk is tagged.
for _, id in CargoRegistry.ids() do
	local def = CargoRegistry.get(id)
	if def ~= nil and not CarryRegistry.has(id) then
		CarryRegistry.register(id, {
			weight = CargoConstants.WEIGHT[def.size] or 0,
			throwable = def.throwable,
			holdOffset = if def.size == "bulky" then CargoConstants.BULKY_HOLD_OFFSET else nil,
		})
	end
end
if not InteractionRegistry.has(CargoConstants.LOAD_KIND) then
	InteractionRegistry.register(CargoConstants.LOAD_KIND, {
		actionText = "Load",
		objectText = "Truck",
		maxDistance = CargoConstants.LOAD_DISTANCE,
	})
end
if not InteractionRegistry.has(CargoConstants.SEARCH_KIND) then
	InteractionRegistry.register(CargoConstants.SEARCH_KIND, {
		actionText = "Search",
		holdDuration = CargoConstants.SEARCH_HOLD,
		maxDistance = CargoConstants.SEARCH_DISTANCE,
	})
end

type Stock = { kind: string?, searched: boolean }

local noiseMade: SignalTyped.Signal<Vector3, number, string> = SignalTyped.new()
local log = Logger.new("CargoServiceServer")
local spawner = CargoSpawnSystem.new()
local claims = CargoClaimTracker.new()
local stock: { [BasePart]: Stock } = {}
local bankHandler: CargoTypes.BankHandler? = nil
local container: Instance? = nil
local counters = { banked = 0, spilled = 0, searched = 0 }
local stoppers: { () -> () } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- An object's cargo kind and id, or nil when it is not cargo.
local function cargoOf(object: Instance): (string?, number?)
	local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	local id = object:GetAttribute(CargoConstants.ID_ATTRIBUTE)
	if type(kind) ~= "string" or not CargoRegistry.has(kind) or type(id) ~= "number" then
		return nil, nil
	end
	return kind, id
end

-- A cargo item as banking sees it, read from the attributes the server stamped on it (never client data).
local function entryOf(object: Instance): CargoTypes.CargoEntry?
	local kind = cargoOf(object)
	local value = object:GetAttribute(CargoConstants.VALUE_ATTRIBUTE)
	if kind == nil or type(value) ~= "number" then
		return nil
	end
	return { kind = kind, value = value }
end

local function idOf(object: Instance): number?
	local _, id = cargoOf(object)
	return id
end

-- Everything a floor probe must look through: every character, plus `extra`.
local function ignoreList(extra: Instance?): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(list, character)
		end
	end
	if extra ~= nil then
		table.insert(list, extra)
	end
	return list
end

local pocketSystem = CargoPocketSystem.new({
	claims = claims,
	spawner = spawner,
	container = function(): Instance?
		return container
	end,
	ignore = function(): { Instance }
		return ignoreList(nil)
	end,
	entryOf = entryOf,
	idOf = idOf,
})

-- Carry's `dropped` (deferred): fragile tiers, spills and drop noise. Pocketing and banking claim the item
-- before they force-drop it, so those never land here.
local function onDropped(_player: Player, object: Instance, reason: CarryTypes.DropReason)
	local kind, id = cargoOf(object)
	if kind == nil or id == nil or claims:isClaimed(id) or not CargoHandlingRules.isImpact(reason) then
		return
	end
	local def = CargoRegistry.get(kind)
	if def == nil or not object:IsA("BasePart") or object.Parent == nil then
		return
	end
	local position = object.Position
	noiseMade:Fire(position, CargoHandlingRules.dropNoise(def), "drop")
	if CargoHandlingRules.shouldSpill(def, reason) then
		claims:claim(id)
		local parent: Instance? = object.Parent
		local floor = spawner:floorUnder(position, ignoreList(object))
		object:Destroy()
		if parent ~= nil then
			VacuumServiceServer:spawnPile(CargoConstants.SPILL_PILE_KIND, floor, parent)
		end
		counters.spilled += 1
		return
	end
	if def.fragile then
		local impacts = object:GetAttribute(CargoConstants.IMPACTS_ATTRIBUTE)
		local count = (if type(impacts) == "number" then impacts else 0) + 1
		object:SetAttribute(CargoConstants.IMPACTS_ATTRIBUTE, count)
		spawner:setValue(object, CargoHandlingRules.valueAfter(def, count))
	end
end

export type CargoServiceServer = {
	dependencies: { string },
	noiseMade: SignalTyped.Signal<Vector3, number, string>,
	start: (self: CargoServiceServer) -> (),
	stop: (self: CargoServiceServer) -> (),
	getState: (self: CargoServiceServer) -> { [string]: any },
	spawnItem: (
		self: CargoServiceServer,
		kind: string,
		floor: CFrame,
		parent: Instance,
		options: CargoTypes.SpawnOptions?
	) -> BasePart,
	reveal: (self: CargoServiceServer, item: Instance) -> (),
	useContainer: (self: CargoServiceServer, parent: Instance?) -> (),
	stockSearchable: (self: CargoServiceServer, part: BasePart, kind: string?) -> (),
	onBanked: (self: CargoServiceServer, handler: CargoTypes.BankHandler) -> (),
	pocket: (self: CargoServiceServer, player: Player) -> (boolean, string?),
	swap: (self: CargoServiceServer, player: Player) -> (boolean, string?),
	load: (self: CargoServiceServer, player: Player, bed: BasePart) -> (boolean, string?),
	search: (self: CargoServiceServer, player: Player, part: BasePart) -> (boolean, string?),
	scatterPockets: (self: CargoServiceServer, player: Player, origin: CFrame) -> (),
	pocketsOf: (self: CargoServiceServer, player: Player) -> { CargoTypes.CargoEntry },
	reset: (self: CargoServiceServer) -> (),
}

local CargoServiceServer: CargoServiceServer

local function tell(player: Player, text: string)
	ToastServiceServer:send(player, { text = text, duration = 2 })
end

local onPocket = RequestHandler.wrap({
	name = "CargoPocket",
	rateLimit = { maxRequests = 6, windowSeconds = 5 },
	handler = function(_data: unknown, player: Player)
		local ok, reason = CargoServiceServer:pocket(player)
		if not ok and reason ~= nil then
			tell(player, reason)
		end
	end,
})

local onSwap = RequestHandler.wrap({
	name = "CargoSwap",
	rateLimit = { maxRequests = 6, windowSeconds = 5 },
	handler = function(_data: unknown, player: Player)
		local ok, reason = CargoServiceServer:swap(player)
		if not ok and reason ~= nil then
			tell(player, reason)
		end
	end,
})

CargoServiceServer = {
	dependencies = {
		"CarryServiceServer",
		"InteractionServiceServer",
		"VacuumServiceServer",
		"ToastServiceServer",
		"StateSyncServiceServer",
	},
	noiseMade = noiseMade,

	--[=[
		Handles Load and Search, Carry's drops, Vacuum's dust bags and the pocket and swap packets; scatters pockets on
		death and leave.
	]=]
	start = function(self)
		InteractionServiceServer:onInteract(CargoConstants.LOAD_KIND, function(player, target)
			if target:IsA("BasePart") then
				local ok, reason = self:load(player, target)
				if not ok and reason ~= nil then
					tell(player, reason)
				end
			end
		end)
		InteractionServiceServer:onInteract(CargoConstants.SEARCH_KIND, function(player, target)
			if target:IsA("BasePart") then
				self:search(player, target)
			end
		end)

		local dropped = CarryServiceServer.dropped:Connect(onDropped)
		local bags = VacuumServiceServer.dustBagReady:Connect(function(_player, floor, parent)
			if parent.Parent ~= nil then
				spawner:spawn(VacuumConstants.DUST_BAG_KIND, floor, parent)
			end
		end)
		local leaving = Players.PlayerRemoving:Connect(function(player)
			pocketSystem:scatter(player, nil)
			pocketSystem:forget(player.UserId)
		end)
		table.insert(stoppers, function()
			dropped:Disconnect()
			bags:Disconnect()
			leaving:Disconnect()
		end)
		table.insert(stoppers, pocketSystem:start())
		table.insert(
			stoppers,
			CargoEvents.packets.Pocket.listen(function(data: boolean, player: Player?)
				if player then
					onPocket(data, player)
				end
			end)
		)
		table.insert(
			stoppers,
			CargoEvents.packets.Swap.listen(function(data: boolean, player: Player?)
				if player then
					onSwap(data, player)
				end
			end)
		)
		table.insert(
			stoppers,
			Observers.observeCharacter(function(player: Player, character: Model)
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local died = if humanoid ~= nil
					then humanoid.Died:Connect(function()
						pocketSystem:scatter(player, nil)
					end)
					else nil
				return function()
					if died ~= nil then
						died:Disconnect()
					end
				end
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	spawnItem = function(_self, kind, floor, parent, options)
		return spawner:spawn(kind, floor, parent, options)
	end,

	reveal = function(_self, item)
		spawner:reveal(item)
	end,

	--[=[
		The shift's container (Office): where searched and scattered items are spawned. Nil = no shift.
	]=]
	useContainer = function(_self, parent)
		container = parent
	end,

	--[=[
		Gives a desk or locker its contents for this shift (nil = empty) and turns its Search prompt on.
	]=]
	stockSearchable = function(_self, part, kind)
		stock[part] = { kind = kind, searched = false }
		InteractionServiceServer:setEnabled(part, true)
	end,

	--[=[
		Sets THE banking handler (Shift). Errors on a second one.
	]=]
	onBanked = function(_self, handler)
		assert(bankHandler == nil, "CargoServiceServer:onBanked: a banking handler is already set")
		bankHandler = handler
	end,

	--[=[
		Moves the hands item into a pocket: claim, record, release from Carry, destroy.
	]=]
	pocket = function(_self, player)
		return pocketSystem:pocket(player)
	end,

	--[=[
		Unpockets into empty hands, or trades a tiny hands item for the oldest pocketed one (spec §6.3).
	]=]
	swap = function(_self, player)
		return pocketSystem:swap(player)
	end,

	--[=[
		Loads the hands item and the pockets onto the truck: the player must stand in the bed; claim → the
		banking handler adds the deposit → destroy. A refused deposit leaves everything as it was.
	]=]
	load = function(_self, player, bed)
		local handler = bankHandler
		local root = rootOf(player)
		if handler == nil then
			return false, "the truck is not taking cargo"
		end
		if root == nil or not CargoBankRules.onBed(bed.CFrame:PointToObjectSpace(root.Position), bed.Size) then
			return false, "stand in the truck bed to load"
		end
		local item = CarryServiceServer:getCarried(player)
		local hands = if item ~= nil then entryOf(item) else nil
		local id = if item ~= nil then idOf(item) else nil
		local deposit, reason = CargoBankRules.deposit(hands, pocketSystem:list(player.UserId), CargoRegistry.get)
		if deposit == nil then
			return false, reason
		end
		if hands ~= nil and (id == nil or not claims:claim(id)) then
			return false, "already loaded"
		end
		local ok, accepted = pcall(handler, player, deposit)
		if not ok then
			log:warn(`banking handler failed: {accepted}`)
		end
		if not ok or accepted ~= true then
			if hands ~= nil and id ~= nil then
				claims:release(id)
			end
			return false, "the truck is not taking cargo"
		end
		pocketSystem:take(player.UserId)
		if item ~= nil and hands ~= nil then
			CarryServiceServer:forceDrop(player, "forced")
			item:Destroy()
		end
		counters.banked += 1
		return true, nil
	end,

	--[=[
		Searches a stocked desk or locker once per shift: what was rolled appears on the floor in front of it.
	]=]
	search = function(_self, player, part)
		local stocked = stock[part]
		if stocked == nil or stocked.searched then
			return false, "already searched"
		end
		stocked.searched = true
		InteractionServiceServer:setEnabled(part, false)
		counters.searched += 1
		noiseMade:Fire(part.Position, CargoConstants.SEARCH_NOISE, "search")
		local kind = stocked.kind
		local parent = container
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if kind == nil or def == nil or parent == nil then
			tell(player, "Nothing useful in here.")
			return true, nil
		end
		local front = part.CFrame * CFrame.new(0, -part.Size.Y / 2, -(part.Size.Z / 2 + 1.5))
		spawner:spawn(kind, front, parent)
		tell(player, `Found: {def.name}`)
		return true, nil
	end,

	--[=[
		Drops a player's pockets around `origin` (M2's catch: where they land). Death and leaving use it too.
	]=]
	scatterPockets = function(_self, player, origin)
		pocketSystem:scatter(player, origin.Position)
	end,

	pocketsOf = function(_self, player)
		return pocketSystem:list(player.UserId)
	end,

	--[=[
		A new shift: pockets emptied (and published), claims forgotten, desks closed until re-stocked. The
		items themselves go with the shift's container (Office).
	]=]
	reset = function(_self)
		claims:clear()
		pocketSystem:clear()
		for part in stock do
			InteractionServiceServer:setEnabled(part, false)
		end
		table.clear(stock)
		container = nil
	end,

	getState = function(_self)
		local stocked = 0
		for _ in stock do
			stocked += 1
		end
		return {
			stocked = stocked,
			hasContainer = container ~= nil,
			hasBankHandler = bankHandler ~= nil,
			counters = table.clone(counters),
			pockets = pocketSystem:counts(),
		}
	end,
}

return CargoServiceServer
