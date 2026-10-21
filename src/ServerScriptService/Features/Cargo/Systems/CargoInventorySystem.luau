--!strict
--[=[
	CargoInventorySystem: the hotbar inventory (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md).
	Five hotbar slots: 1 the vacuum, 2-5 four item slots (CargoInventoryTracker).

	- E on cargo (Carry's pick-up prompt, routed here by CarryServiceServer:setPickUpRoute): a small item is pocketed
	  straight into the first free item slot (its grime locks first, as on any first pick-up; claim, record, destroy)
	  and the hands stay as they were; a big item takes the first free slot and both hands (Carry), the small hands
	  item going back into its own slot first and the vacuum away (it comes back by itself after the drop).
	  CargoInventoryRules.pickUpPlan decides.
	- `select` (the `Select` packet: keys 1-5, the d-pad, a hotbar tap or click): CargoInventoryRules.selectPlan. The small hands
	  item goes back into its slot (`stash`: claim, record, release from Carry, destroy), a filled slot's item is drawn
	  into one hand (respawned at the feet and handed to Carry once Carry has adopted it, within HAND_WAIT, else put back
	  in its slot), and the vacuum comes out or goes away (VacuumServiceServer:setEquipped). A big item in the hands
	  locks every slot.
	- Whatever ends the hands item's hold (a drop, a throw, a catch, a Load) empties its slot (`reconcile`, on Carry's
	  `dropped` and before every request).
	- `take` empties the inventory for a Load; `scatter` empties it and puts the pocketed items back in the world
	  (CargoScatterSystem).
	- `loadOf` is the player's whole load for Carry's walk (CarrySpeedSystem.setLoadSource): SMALL_LOAD per small item
	  plus the big hands item's weight (CargoInventoryRules.load).
	- Published per player: CargoInventoryUtils.published (each item slot's kind, known value and jackpot name, the
	  hands slot and the empty-hands choice).

	Spec-exempt shell (Carry, Vacuum, Instances, Players, ByteNet, Heartbeat); the decisions are the specced
	CargoInventoryRules and CargoInventoryTracker.

	@class CargoInventorySystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoServer = ServerScriptService.Features.Cargo
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoEvents = require(CargoShared.Net.CargoEvents)
local CargoInventoryRules = require(CargoShared.Rules.CargoInventoryRules)
local CargoInventoryUtils = require(CargoShared.Utils.CargoInventoryUtils)
local CargoClaimTracker = require(CargoServer.State.CargoClaimTracker)
local CargoInventoryTracker = require(CargoServer.State.CargoInventoryTracker)
local CargoScatterSystem = require(CargoServer.Systems.CargoScatterSystem)
local CargoSpawnSystem = require(CargoServer.Systems.CargoSpawnSystem)
local CarryServiceServer = require(ServerScriptService.Features.Carry.CarryServiceServer)
local CarrySpeedSystem = require(ServerScriptService.Features.Carry.Systems.CarrySpeedSystem)
local VacuumToolSystem = require(ServerScriptService.Features.Vacuum.Systems.VacuumToolSystem)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

type CargoEntry = CargoTypes.CargoEntry
type ItemDef = CargoTypes.ItemDef

export type Deps = {
	claims: CargoClaimTracker.CargoClaimTracker,
	spawner: CargoSpawnSystem.CargoSpawnSystem,
	-- The shift's container (where items come back into the world); nil = no shift.
	container: () -> Instance?,
	-- What a floor probe looks through (every character).
	ignore: () -> { Instance },
	entryOf: (object: Instance) -> CargoEntry?,
	idOf: (object: Instance) -> number?,
	-- A valuable's first pick-up (its grime locks): run on an item about to be pocketed.
	lock: (object: Instance, player: Player) -> (),
	-- An item went straight from the world into the inventory (analytics' pick-up), just before it is destroyed.
	collected: (player: Player, object: Instance) -> (),
}

export type Counts = { pocketed: number, held: number, drawn: number, stashed: number, scattered: number }

export type CargoInventorySystem = {
	-- Routes cargo pick-ups here, answers the Select packet, follows Carry's drops and samples every character's
	-- position (for a scatter); returns the stopper.
	start: (self: CargoInventorySystem) -> () -> (),
	forget: (self: CargoInventorySystem, userId: number) -> (),
	pickUp: (self: CargoInventorySystem, player: Player, item: Instance) -> (boolean, string?),
	select: (self: CargoInventorySystem, player: Player, slot: number) -> (boolean, string?),
	list: (self: CargoInventorySystem, userId: number) -> { CargoEntry },
	take: (self: CargoInventorySystem, userId: number) -> { CargoEntry },
	scatter: (self: CargoInventorySystem, player: Player, origin: Vector3?) -> (),
	loadOf: (self: CargoInventorySystem, player: Player) -> number?,
	clear: (self: CargoInventorySystem) -> (),
	counts: (self: CargoInventorySystem) -> Counts,
}

-- How long a drawn item may take to reach the hands before it is put back in its slot.
local HAND_WAIT = 0.5

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- An object's cargo catalog entry (nil for anything that is not cargo).
local function defOf(object: Instance): ItemDef?
	local kind = object:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	return if type(kind) == "string" then CargoRegistry.get(kind) else nil
end

local CargoInventorySystem = {}

function CargoInventorySystem.new(deps: Deps): CargoInventorySystem
	local inventory = CargoInventoryTracker.new()
	-- The hands slot's item (Carry's) per player, and the players whose draw is under way.
	local handsItem: { [number]: Instance } = {}
	local drawing: { [number]: boolean } = {}
	local scatterer =
		CargoScatterSystem.new({ spawner = deps.spawner, container = deps.container, ignore = deps.ignore })
	local counts: Counts = { pocketed = 0, held = 0, drawn = 0, stashed = 0, scattered = 0 }

	local function publish(userId: number)
		local fields =
			CargoInventoryUtils.published(inventory:slots(userId), inventory:hands(userId), inventory:selected(userId))
		StateSyncPublicPlayerStore.set(userId, fields.set)
		for _, field in fields.cleared do
			StateSyncPublicPlayerStore.clearField(userId, field)
		end
	end

	-- Publishes the inventory and re-applies the player's walk speed for their load.
	local function changed(player: Player)
		publish(player.UserId)
		CarrySpeedSystem.apply(player)
	end

	-- Empties the hands slot once its item is no longer in the player's hands (dropped, thrown, caught, banked).
	local function reconcile(player: Player)
		local userId = player.UserId
		local index = inventory:hands(userId)
		if index == nil or drawing[userId] then
			return
		end
		local item: Instance? = handsItem[userId]
		if item ~= nil and CarryServiceServer:getCarried(player) == item then
			return
		end
		inventory:take(userId, index)
		handsItem[userId] = nil
		changed(player)
	end

	-- Puts the small hands item back into its own slot: claim (the only step that can refuse, first), record its state
	-- now, release from Carry, destroy. True when the hands are empty of inventory items afterwards.
	local function stash(player: Player): boolean
		local userId = player.UserId
		local index = inventory:hands(userId)
		local item: Instance? = handsItem[userId]
		if index == nil or item == nil then
			return true
		end
		if CarryServiceServer:getCarried(player) ~= item then
			reconcile(player)
			return true
		end
		local entry = deps.entryOf(item)
		local id = deps.idOf(item)
		if entry == nil or id == nil or not deps.claims:claim(id) then
			return false
		end
		inventory:replace(userId, index, entry)
		inventory:setHands(userId, nil)
		handsItem[userId] = nil
		CarryServiceServer:forceDrop(player, "forced")
		item:Destroy()
		counts.stashed += 1
		return true
	end

	-- Brings item slot `index`'s entry back into the world at the player's feet and into their hands. Carry adopts the
	-- new item from its tag observer, which can run a few frames later (it sets the interaction kind attribute when it
	-- has), so wait for that, up to HAND_WAIT seconds. If the player, the item or the hold fails, the item goes back in
	-- its slot.
	local function draw(player: Player, index: number, root: BasePart, parent: Instance)
		local userId = player.UserId
		local entry = inventory:get(userId, index)
		if entry == nil then
			return
		end
		drawing[userId] = true
		inventory:setHands(userId, index)
		local floor = deps.spawner:floorUnder(root.Position, deps.ignore())
		local part = deps.spawner:spawn(entry.kind, floor, parent, {
			value = entry.value,
			appraisal = entry.appraisal,
			artKit = if entry.visual ~= nil then entry.visual.kitId else nil,
			source = "hotbar",
			overtime = entry.overtime,
		})
		handsItem[userId] = part
		task.spawn(function()
			local waited = 0
			local held = false
			while part.Parent ~= nil and player.Parent ~= nil and waited <= HAND_WAIT do
				if part:GetAttribute(InteractionConstants.KIND_ATTRIBUTE) == CarryConstants.INTERACTION_KIND then
					held = CarryServiceServer:pickUp(player, part)
					break
				end
				waited += task.wait()
			end
			drawing[userId] = nil
			if held then
				counts.drawn += 1
				changed(player)
				return
			end
			-- Never left on the floor: back in its slot.
			local id = deps.idOf(part)
			if part.Parent ~= nil and (id == nil or deps.claims:claim(id)) then
				part:Destroy()
			end
			if inventory:hands(userId) == index then
				inventory:setHands(userId, nil)
			end
			handsItem[userId] = nil
			if player.Parent ~= nil then
				changed(player)
			end
		end)
	end

	-- The hotbar slot chosen now: the hands slot's, else the vacuum's when it is out, else the empty-hands choice.
	local function chosen(player: Player): number
		local hands = inventory:hands(player.UserId)
		if hands ~= nil then
			return hands + 1
		end
		if VacuumToolSystem.isEquipped(player.Character) then
			return CargoConstants.VACUUM_SLOT
		end
		local stored = inventory:selected(player.UserId)
		return if stored == CargoConstants.VACUUM_SLOT then 0 else stored
	end

	local system: CargoInventorySystem
	system = {
		start = function(self)
			CarryServiceServer:setPickUpRoute(function(player: Player, target: Instance): boolean
				if defOf(target) == nil or deps.idOf(target) == nil then
					return false
				end
				local ok, reason = self:pickUp(player, target)
				if not ok and reason ~= nil then
					ToastServiceServer:send(player, { text = reason, duration = 2 })
				end
				return true
			end)
			CarrySpeedSystem.setLoadSource(function(player: Player): number?
				return self:loadOf(player)
			end)
			local onSelect = RequestHandler.wrap({
				name = "CargoSelect",
				rateLimit = { maxRequests = 20, windowSeconds = 5 },
				handler = function(data: unknown, player: Player)
					if type(data) ~= "number" then
						return
					end
					local ok, reason = self:select(player, data)
					if not ok and reason ~= nil then
						ToastServiceServer:send(player, { text = reason, duration = 2 })
					end
				end,
			})
			local stopSelect = CargoEvents.packets.Select.listen(function(data: number, player: Player?)
				if player then
					onSelect(data, player)
				end
			end)
			local dropped = CarryServiceServer.dropped:Connect(function(player: Player)
				reconcile(player)
			end)
			local stopSampling = scatterer:start()
			return function()
				stopSampling()
				dropped:Disconnect()
				stopSelect()
				CarryServiceServer:setPickUpRoute(nil)
				CarrySpeedSystem.setLoadSource(nil)
			end
		end,

		forget = function(_self, userId)
			scatterer:forget(userId)
			handsItem[userId] = nil
			drawing[userId] = nil
			inventory:forget(userId)
		end,

		pickUp = function(_self, player, item)
			reconcile(player)
			local userId = player.UserId
			local def = defOf(item)
			local id = deps.idOf(item)
			if def == nil or id == nil or deps.claims:isClaimed(id) then
				return false, "not cargo"
			end
			if item:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE) ~= nil then
				return false, "already carried"
			end
			if drawing[userId] then
				return false, "not now"
			end
			local carried = CarryServiceServer:getCarried(player)
			local carriedDef = if carried ~= nil then defOf(carried) else nil
			local handsBig = carried ~= nil and (carriedDef == nil or not CargoInventoryRules.isSmall(carriedDef))
			local free = inventory:firstFree(userId)
			local plan, reason = CargoInventoryRules.pickUpPlan(def, free, handsBig)
			if plan == nil or free == nil then
				return false, reason
			end
			if plan == "pocket" then
				deps.lock(item, player)
				local entry = deps.entryOf(item)
				if entry == nil or not deps.claims:claim(id) then
					return false, "already taken"
				end
				inventory:put(userId, free, entry)
				-- An empty slot chosen with empty hands that this item now fills is no longer an empty-hands choice.
				if inventory:selected(userId) == free + 1 then
					inventory:setSelected(userId, 0)
				end
				deps.collected(player, item)
				item:Destroy()
				counts.pocketed += 1
				changed(player)
				return true, nil
			end
			-- A big item: the small hands item back in its slot, the vacuum away until it is dropped, then both hands.
			if not stash(player) or CarryServiceServer:getCarried(player) ~= nil then
				return false, "hands full"
			end
			VacuumServiceServer:setEquipped(player, false, true)
			local entry = deps.entryOf(item)
			if entry == nil then
				return false, "not cargo"
			end
			inventory:put(userId, free, entry)
			inventory:setHands(userId, free)
			handsItem[userId] = item
			local ok, why = CarryServiceServer:pickUp(player, item)
			if not ok then
				inventory:take(userId, free)
				handsItem[userId] = nil
				changed(player)
				return false, why
			end
			inventory:setSelected(userId, free + 1)
			counts.held += 1
			changed(player)
			return true, nil
		end,

		select = function(_self, player, slot)
			reconcile(player)
			local userId = player.UserId
			if drawing[userId] then
				return false, "not now"
			end
			local carried = CarryServiceServer:getCarried(player)
			local hands = inventory:hands(userId)
			local carriedDef = if carried ~= nil then defOf(carried) else nil
			-- Anything in the hands that is not a small inventory item locks the hotbar like a big one.
			local handsBig = carried ~= nil
				and (hands == nil or carriedDef == nil or not CargoInventoryRules.isSmall(carriedDef))
			local filled: { [number]: boolean } = {}
			for index in inventory:slots(userId) do
				filled[index] = true
			end
			local plan, reason = CargoInventoryRules.selectPlan(
				slot,
				{ selected = chosen(player), hands = hands, handsBig = handsBig, filled = filled }
			)
			if plan == nil then
				return false, reason
			end
			local root = rootOf(player)
			local parent = deps.container()
			local drawSlot = plan.draw
			if drawSlot ~= nil and (root == nil or parent == nil or parent.Parent == nil) then
				return false, "not now"
			end
			if plan.stash and not stash(player) then
				return false, "not now"
			end
			VacuumServiceServer:setEquipped(player, plan.vacuum)
			if drawSlot ~= nil and root and parent then
				draw(player, drawSlot, root, parent)
			end
			inventory:setSelected(userId, plan.selected)
			changed(player)
			return true, nil
		end,

		list = function(_self, userId)
			return inventory:pocketed(userId)
		end,

		take = function(_self, userId)
			local list = inventory:takePocketed(userId)
			handsItem[userId] = nil
			publish(userId)
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				CarrySpeedSystem.apply(player)
			end
			return list
		end,

		scatter = function(_self, player, origin)
			local list = inventory:takePocketed(player.UserId)
			handsItem[player.UserId] = nil
			changed(player)
			counts.scattered += scatterer:scatter(player, origin, list)
		end,

		loadOf = function(_self, player)
			local carried = CarryServiceServer:getCarried(player)
			local carriedDef = if carried ~= nil then defOf(carried) else nil
			if carried ~= nil and carriedDef == nil then
				-- Not cargo: Carry's own weight for it.
				return nil
			end
			local userId = player.UserId
			local small = 0
			for _, entry in inventory:slots(userId) do
				local def = CargoRegistry.get(entry.kind)
				if def ~= nil and CargoInventoryRules.isSmall(def) then
					small += 1
				end
			end
			-- A small item in the hands that is not one of the slots (never expected) still weighs.
			if carriedDef ~= nil and CargoInventoryRules.isSmall(carriedDef) and handsItem[userId] ~= carried then
				small += 1
			end
			return CargoInventoryRules.load(small, carriedDef)
		end,

		clear = function(_self)
			inventory:clear()
			table.clear(handsItem)
			table.clear(drawing)
			for _, player in Players:GetPlayers() do
				publish(player.UserId)
				CarrySpeedSystem.apply(player)
			end
		end,

		counts = function(_self)
			return table.clone(counts)
		end,
	}
	return system
end

return CargoInventorySystem
