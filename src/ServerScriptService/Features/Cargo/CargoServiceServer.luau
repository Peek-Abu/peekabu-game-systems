--!strict
--[=[
	CargoServiceServer: Cleanup Crew's cargo (spec §4 "Cargo and carrying", §6.4). Every catalog item is a
	Carry kind (weight by size, the bulky cart held far out) spawned by CargoSpawnSystem. On top of Carry:

	- Pockets (CargoPocketSystem): the `pocket` and `swap` packets; two tiny-only slots published as
	  `pocket1` / `pocket2`; scattered where their owner dies or leaves.
	- Handling (Carry's `dropped`, which SignalPlus delivers deferred): a fragile item loses a value tier per
	  impact; a thrown recycling box spills only after an off-truck landing; every drop fires `noiseMade`
	  (the M2 Noise seam).
	- Traits (M2, CargoTraitSystem): rattly items pulse a noise while carried; the jug leaves a slippery puddle.
	- Search: desks and lockers stocked per shift (`stockSearchable`); a short hold gives what was rolled.
	  Every completed search fires `searched` with the container (the Office dresses it open).
	- Banking: the `cargo-load` interaction on the truck bed. Claim (CargoClaimTracker) → add (the game's
	  `onBanked` handler) → destroy, in one synchronous step, so two Loads never count one item twice.
	- Grime (the loot loop, docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md, CargoGrimeSystem):
	  valuables spawn grimy; vacuuming one (Vacuum's grime channel) cleans it, raises its value and appraises it at
	  65% (a small sticky slip to the crew near it); an unappraised valuable banked is appraised at the truck (a
	  slip to the banker). Carry's `pickedUp` seals a dirty valuable as it is (its grime locks on the first pick-up).
	- Feel (M3): every Load is announced (`Banked`, built by CargoFeedbackUtils.banked: the client swoops the
	  items into the truck, cha-chings and floats "+N"); drops (here), rattles and searches (CargoTraitSystem)
	  play positional sounds, silent while their CargoAssets ids are pending.

	Spec-exempt shell (Instances, Players, ByteNet, signals); the rules are the specced CargoHandlingRules,
	CargoBankRules, CargoClaimTracker and CargoPocketTracker.

	@class CargoServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoServer = ServerScriptService.Features.Cargo
local CarryShared = ReplicatedStorage.Shared.Features.Carry
local Observers = require(ReplicatedStorage.Packages.Observers)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local CarryConstants = require(CarryShared.Data.CarryConstants)
local CarryRegistry = require(CarryShared.Data.CarryRegistry)
local CarryTypes = require(CarryShared.Data.CarryTypes)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoEvents = require(CargoShared.Net.CargoEvents)
local CargoFeedbackUtils = require(CargoShared.Utils.CargoFeedbackUtils)
local CargoHandlingRules = require(CargoShared.Rules.CargoHandlingRules)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local CargoClaimTracker = require(CargoServer.State.CargoClaimTracker)
local CargoPocketSystem = require(CargoServer.Systems.CargoPocketSystem)
local CargoSpawnSystem = require(CargoServer.Systems.CargoSpawnSystem)
local CargoGroundSystem = require(CargoServer.Systems.CargoGroundSystem)
local CargoGrimeSystem = require(CargoServer.Systems.CargoGrimeSystem)
local CargoLoadSystem = require(CargoServer.Systems.CargoLoadSystem)
local CargoTraitSystem = require(CargoServer.Systems.CargoTraitSystem)
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
		actionText = "Bank cargo",
		objectText = "Recovery Unit",
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

type Stock = { kind: string?, appraisal: CargoTypes.Appraisal?, searched: boolean }

local noiseMade: SignalTyped.Signal<Vector3, number, string, { number }> = SignalTyped.new()
local searched: SignalTyped.Signal<BasePart> = SignalTyped.new()
local spawner = CargoSpawnSystem.new()
local claims = CargoClaimTracker.new()
local stock: { [BasePart]: Stock } = {}
local bankHandler: CargoTypes.BankHandler? = nil
local container: Instance? = nil
local counters = { banked = 0, spilled = 0, searched = 0 }
local stoppers: { () -> () } = {}

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
local entryOf = CargoFeedbackUtils.entryOf

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

-- Rattles and puddles (M2). Claimed items (banked, pocketed) never splash.
local traits = CargoTraitSystem.new({
	noiseMade = noiseMade,
	spawner = spawner,
	container = function(): Instance?
		return container
	end,
	ignore = ignoreList,
	isClaimed = function(object: Instance): boolean
		local id = idOf(object)
		return id ~= nil and claims:isClaimed(id)
	end,
})

-- Cleaning grimy valuables (the loot loop): appraisals are stamped to the crew near them, or to the banker at the truck.
local grime = CargoGrimeSystem.new({
	spawner = spawner,
	now = function(): number
		return Workspace:GetServerTimeNow()
	end,
	sound = function(position: Vector3, id: string)
		traits:sound(position, id)
	end,
})

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

local loader = CargoLoadSystem.new({
	claims = claims,
	entryOf = entryOf,
	idOf = idOf,
	handler = function()
		return bankHandler
	end,
	container = function()
		return container
	end,
	isPresent = function(player)
		return player.Parent == Players
	end,
	getCarried = function(player)
		return CarryServiceServer:getCarried(player)
	end,
	forceDrop = function(player)
		CarryServiceServer:forceDrop(player, "forced")
	end,
	pockets = {
		list = function(userId)
			return pocketSystem:list(userId)
		end,
		take = function(userId)
			pocketSystem:take(userId)
		end,
	},
	tell = function(player, text)
		ToastServiceServer:send(player, { text = text, duration = 2 })
	end,
	announce = function(deposit, from, bed, credited, banker)
		CargoEvents.packets.Banked.sendToAll(CargoFeedbackUtils.banked(deposit, from, bed.Position, bed.Size, credited))
		counters.banked += 1
		grime:banked(deposit, banker)
	end,
})

local ground = CargoGroundSystem.new(spawner, ignoreList, function(player, object, reason, landed)
	if not landed or loader:settled(player, object) then
		return
	end
	local kind, id = cargoOf(object)
	local def = if kind ~= nil then CargoRegistry.get(kind) else nil
	if def ~= nil and id ~= nil and CargoHandlingRules.shouldSpill(def, reason) and claims:claim(id) then
		local parent = object.Parent
		local floor = spawner:floorUnder(object.Position, ignoreList(object))
		object:Destroy()
		if parent ~= nil then
			VacuumServiceServer:spawnPile(CargoConstants.SPILL_PILE_KIND, floor, parent)
		end
		counters.spilled += 1
	end
end)

-- Carry's `dropped` (deferred): fragile tiers, spills and drop noise. Pocketing and banking claim the item
-- before they force-drop it, so those never land here.
local function onDropped(player: Player, object: Instance, reason: CarryTypes.DropReason)
	local kind, id = cargoOf(object)
	if kind == nil or id == nil or claims:isClaimed(id) or not CargoHandlingRules.isImpact(reason) then
		return
	end
	local def = CargoRegistry.get(kind)
	if def == nil or not object:IsA("BasePart") or object.Parent == nil then
		return
	end
	local position = object.Position
	noiseMade:Fire(position, CargoHandlingRules.dropNoise(def), "drop", { player.UserId })
	traits:sound(position, CargoFeedbackUtils.dropSound(def))
	if def.fragile then
		local impacts = object:GetAttribute(CargoConstants.IMPACTS_ATTRIBUTE)
		local count = (if type(impacts) == "number" then impacts else 0) + 1
		object:SetAttribute(CargoConstants.IMPACTS_ATTRIBUTE, count)
		spawner:reprice(object)
	end
	ground:release(object, reason, player)
end

export type CargoServiceServer = {
	dependencies: { string },
	noiseMade: SignalTyped.Signal<Vector3, number, string, { number }>,
	searched: SignalTyped.Signal<BasePart>,
	start: (self: CargoServiceServer) -> (),
	stop: (self: CargoServiceServer) -> (),
	getState: (self: CargoServiceServer) -> { [string]: unknown },
	spawnItem: (
		self: CargoServiceServer,
		kind: string,
		floor: CFrame,
		parent: Instance,
		options: CargoTypes.SpawnOptions?
	) -> BasePart,
	reveal: (self: CargoServiceServer, item: Instance) -> (),
	useContainer: (self: CargoServiceServer, parent: Instance?) -> (),
	stockSearchable: (self: CargoServiceServer, part: BasePart, kind: string?, appraisal: CargoTypes.Appraisal?) -> (),
	onBanked: (self: CargoServiceServer, handler: CargoTypes.BankHandler) -> (),
	pocket: (self: CargoServiceServer, player: Player) -> (boolean, string?),
	swap: (self: CargoServiceServer, player: Player) -> (boolean, string?),
	load: (self: CargoServiceServer, player: Player, bed: BasePart) -> (boolean, string?),
	search: (self: CargoServiceServer, player: Player, part: BasePart) -> (boolean, string?),
	scatterPockets: (self: CargoServiceServer, player: Player, origin: CFrame) -> (),
	pocketsOf: (self: CargoServiceServer, player: Player) -> { CargoTypes.CargoEntry },
	reset: (self: CargoServiceServer) -> (),
}

local SearchPlacement = require(CargoServer.Systems.CargoSearchPlacementSystem)
local CargoServiceServer: CargoServiceServer

local function tell(player: Player, text: string)
	ToastServiceServer:send(player, { text = text, duration = 2 })
end

CargoServiceServer = {
	dependencies = {
		"CarryServiceServer",
		"InteractionServiceServer",
		"VacuumServiceServer",
		"ToastServiceServer",
		"StateSyncServiceServer",
		"SoundServiceServer",
	},
	noiseMade = noiseMade,
	searched = searched,

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
		local lifted = CarryServiceServer.pickedUp:Connect(function(player, object)
			if cargoOf(object) ~= nil then
				grime:pickedUp(object, player)
			end
		end)
		local bags = VacuumServiceServer.dustBagReady:Connect(function(_player, floor, parent)
			if parent.Parent ~= nil then
				spawner:spawn(VacuumConstants.DUST_BAG_KIND, floor, parent)
			end
		end)
		table.insert(stoppers, grime:start())
		local leaving = Players.PlayerRemoving:Connect(function(player)
			pocketSystem:scatter(player, nil)
			pocketSystem:forget(player.UserId)
		end)
		table.insert(stoppers, function()
			dropped:Disconnect()
			lifted:Disconnect()
			bags:Disconnect()
			leaving:Disconnect()
		end)
		table.insert(stoppers, pocketSystem:start())
		traits:start()
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
		traits:stop()
		ground:stop()
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
		Gives a desk or locker its contents for this shift (nil = empty; a valuable with its appraisal) and turns its
		Search prompt on.
	]=]
	stockSearchable = function(_self, part, kind, appraisal)
		stock[part] = { kind = kind, appraisal = appraisal, searched = false }
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
		return loader:load(player, bed)
	end,

	--[=[
		Searches a stocked desk or locker once per shift: what was rolled appears on the floor in front of it.
	]=]
	search = function(_self, player, part)
		local stocked = stock[part]
		if stocked == nil or stocked.searched then
			return false, "already searched"
		end
		local landing, reason = SearchPlacement.forSearch(part, stocked.kind, container)
		if reason ~= nil then
			return false, reason
		end
		stocked.searched = true
		InteractionServiceServer:setEnabled(part, false)
		counters.searched += 1
		searched:Fire(part)
		noiseMade:Fire(part.Position, CargoConstants.SEARCH_NOISE, "search", { player.UserId })
		tell(player, SearchPlacement.deliver(stocked.kind, container, landing, spawner, stocked.appraisal))
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
		ground:stop()
		grime:reset()
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
			puddles = traits:puddles(),
		}
	end,
}

return CargoServiceServer
