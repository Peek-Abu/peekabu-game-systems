--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local InventoryEvents = require(ReplicatedStorage.Shared.Events.InventoryEvents)
local InventoryUtils = require(ReplicatedStorage.Shared.Modules.Utils.InventoryUtils)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDataConstants = require(ServerScriptService.Modules.Constants.PlayerDataConstants)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)

PlayerDataConstants.registerProfilePath("inventory", {})

local log = Logger.new("InventoryServiceServer")

export type RemoveItemRequest = {
	item: PlayerDataTypes.InventoryItem,
	amount: number,
}

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	The module below is one annotated table literal (`local InventoryServiceServer:
	InventoryServiceServer = { ... }`). Annotating the literal makes Luau push each
	signature from this interface DOWN into the matching method body, so the methods
	need NO inline type annotations — `self` and every parameter are typed from here.
	Types live in exactly one place, and there are zero casts.

	The interface is declared explicitly (rather than `typeof(InventoryServiceServer)`)
	so signatures are pinned exactly as written and never widen as values flow into
	struct fields. A nominal interface never widens.
]=]
export type InventoryServiceServer = {
	dependencies: { string },
	MAX_INVENTORY_SIZE: number,

	broadcastInventoryDelta: (
		self: InventoryServiceServer,
		userId: number,
		action: string,
		item: PlayerDataTypes.InventoryItem
	) -> (),
	broadcastInventoryBatchDelta: (
		self: InventoryServiceServer,
		userId: number,
		added: { PlayerDataTypes.InventoryItem },
		removed: { PlayerDataTypes.InventoryItem },
		updated: { PlayerDataTypes.InventoryItem }
	) -> (),
	getInventory: (self: InventoryServiceServer, userId: number) -> { PlayerDataTypes.InventoryItem },
	hasItem: (
		self: InventoryServiceServer,
		userId: number,
		targetItem: PlayerDataTypes.InventoryItem,
		amount: number?
	) -> boolean,
	_mutateInventory: (
		self: InventoryServiceServer,
		userId: number,
		fn: (inventory: { PlayerDataTypes.InventoryItem }) -> boolean?
	) -> boolean,
	addItem: (self: InventoryServiceServer, userId: number, item: PlayerDataTypes.InventoryItem) -> boolean,
	addItems: (self: InventoryServiceServer, userId: number, items: { PlayerDataTypes.InventoryItem }) -> boolean,
	removeItem: (
		self: InventoryServiceServer,
		userId: number,
		targetItem: PlayerDataTypes.InventoryItem,
		amount: number
	) -> boolean,
	removeItems: (self: InventoryServiceServer, userId: number, requests: { RemoveItemRequest }) -> boolean,
	getState: (self: InventoryServiceServer) -> { [string]: any },
}

local InventoryServiceServer: InventoryServiceServer = {
	dependencies = { "PlayerDataServiceServer" },

	MAX_INVENTORY_SIZE = 100,

	--[=[
		Broadcasts inventory changes to the specified player.
		@param userId number -- The user ID of the player
		@param action string -- The action type ("add", "remove", or "update")
		@param item PlayerDataTypes.InventoryItem -- The item that was changed
	]=]
	broadcastInventoryDelta = function(_self, userId, action, item)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(action) == "string", `action must be a string, got {type(action)}`)
		assert(
			action == "add" or action == "remove" or action == "update",
			`action must be "add", "remove", or "update", got "{action}"`
		)
		assert(type(item) == "table", `item must be a table, got {type(item)}`)

		local player = Players:GetPlayerByUserId(userId)
		if player then
			InventoryEvents.packets.InventoryDelta.sendTo({
				userId = userId,
				action = action,
				item = item,
			}, player)
		end
	end,

	--[=[
		Broadcasts batch inventory changes to the specified player.
		@param userId number -- The user ID of the player
		@param added {PlayerDataTypes.InventoryItem} -- Items that were added
		@param removed {PlayerDataTypes.InventoryItem} -- Items that were removed
		@param updated {PlayerDataTypes.InventoryItem} -- Items that were updated (quantity changed)
	]=]
	broadcastInventoryBatchDelta = function(_self, userId, added, removed, updated)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)

		local player = Players:GetPlayerByUserId(userId)
		if player then
			InventoryEvents.packets.InventoryBatchDelta.sendTo({
				userId = userId,
				added = added,
				removed = removed,
				updated = updated,
			}, player)
		end
	end,

	--[=[
		Gets the inventory for a specified user.
		@param userId number -- The user ID to get inventory for
		@return {PlayerDataTypes.InventoryItem} -- Array of inventory items
	]=]
	getInventory = function(_self, userId)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)

		local profile = PlayerDataService:getProfile(userId)
		return profile and profile.inventory or {}
	end,

	--[=[
		Checks if a player has a specific item in their inventory.
		@param userId number -- The user ID to check
		@param targetItem PlayerDataTypes.InventoryItem -- The item to check for
		@param amount number? -- Optional amount required (defaults to 1)
		@return boolean -- True if the player has the item (and quantity), false otherwise
	]=]
	hasItem = function(self, userId, targetItem, amount)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(targetItem) == "table", `targetItem must be a table, got {type(targetItem)}`)
		if amount ~= nil then
			assert(
				type(amount) == "number" and amount > 0,
				`amount must be a positive number, got {type(amount)}: {amount}`
			)
		end

		local inventory = self:getInventory(userId)
		local idx = InventoryUtils.findMatchingItemIndex(inventory, targetItem)
		if not idx then
			return false
		end

		local item = inventory[idx]
		local required = amount or 1
		return (item.quantity or 1) >= required
	end,

	--[=[
		Mutates this service's slice of the profile (the "inventory" path). This is the ONLY
		place the "inventory" path string is written — every add/remove method routes through
		here, so there is no stringly-typed path for callers to typo, and the mutator's
		`inventory` argument is typed without an inline annotation at each call site.

		This is the recommended pattern for any service that owns a profile slice: keep the
		registered path encapsulated in one private accessor instead of repeating the string.

		@param userId number -- The user ID
		@param fn (inventory: { PlayerDataTypes.InventoryItem }) -> boolean? -- Mutator; return true if data changed
		@return boolean -- True if the mutation changed data
	]=]
	_mutateInventory = function(_self, userId, fn)
		return PlayerDataService:mutate(userId, "inventory", fn)
	end,

	--[=[
		Adds an item to a player's inventory.
		@param userId number -- The user ID to add item to
		@param item PlayerDataTypes.InventoryItem -- The item to add
		@return boolean -- True if the item was successfully added, false otherwise
	]=]
	addItem = function(self, userId, item)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(item) == "table", `item must be a table, got {type(item)}`)
		assert(item.itemType, `item must have an itemType field`)

		local result: InventoryUtils.AddResult

		local mutated = self:_mutateInventory(userId, function(inventory)
			-- Check bounds before trying to add new stack
			local idx = InventoryUtils.findMatchingItemIndex(inventory, item)
			if not idx and #inventory >= self.MAX_INVENTORY_SIZE then
				log:warn(`Player {userId} exceeded max inventory size`)
				return false
			end

			result = InventoryUtils.tryAdd(inventory, item)
			if not result.success then
				log:warn("Attempted to add a unique item that already exists:", item.itemType, item.instanceId)
				return false
			end
			return true
		end)

		if not mutated or not result.success or not result.resultItem then
			return false
		end
		self:broadcastInventoryDelta(userId, result.action, result.resultItem)
		return true
	end,

	--[=[
		Adds multiple items to a player's inventory in a single mutation.
		This is a BEST-EFFORT function: it skips invalid items and processes the rest.
		If you need All-or-Nothing guarantees, use PlayerDataService:transaction() instead.

		@param userId number -- The user ID to add items to
		@param items {PlayerDataTypes.InventoryItem} -- The items to add
		@return boolean -- True if any item was successfully added, false otherwise
	]=]
	addItems = function(self, userId, items)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(items) == "table", `items must be a table, got {type(items)}`)
		if #items == 0 then
			return true
		end

		local added: { PlayerDataTypes.InventoryItem } = {}
		local updated: { PlayerDataTypes.InventoryItem } = {}

		local mutated = self:_mutateInventory(userId, function(inventory)
			local didMutate = false
			for _, item in items do
				assert(item.itemType, `each item must have an itemType field`)

				local idx = InventoryUtils.findMatchingItemIndex(inventory, item)
				if not idx and #inventory >= self.MAX_INVENTORY_SIZE then
					-- Inventory is full for NEW stacks, but later items in the batch may stack
					-- onto existing entries (no new slot needed), so skip this one and keep going.
					log:warn(`Player {userId} at max inventory size; skipping new item {item.itemType}`)
					continue
				end

				local result = InventoryUtils.tryAdd(inventory, item)
				if not result.success then
					log:warn("Failed to add item in batch:", item.itemType, item.instanceId)
					continue
				end
				didMutate = true
				if result.resultItem then
					if result.action == "add" then
						table.insert(added, result.resultItem)
					else
						table.insert(updated, result.resultItem)
					end
				end
			end
			return didMutate
		end)

		if not mutated then
			return false
		end

		self:broadcastInventoryBatchDelta(userId, added, {}, updated)
		return true
	end,

	--[=[
		Removes a quantity of an item from a player's inventory.
		Uses InventoryUtils.tryRemove for all quantity and unique-item logic.

		@param userId number -- The user ID to remove item from
		@param targetItem PlayerDataTypes.InventoryItem -- The item to remove
		@param amount number -- The quantity to remove
		@return boolean -- True if the item was successfully removed, false otherwise
	]=]
	removeItem = function(self, userId, targetItem, amount)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(targetItem) == "table", `targetItem must be a table, got {type(targetItem)}`)
		assert(
			type(amount) == "number" and amount > 0,
			`amount must be a positive number, got {type(amount)}: {amount}`
		)

		local result: InventoryUtils.RemoveResult

		local mutated = self:_mutateInventory(userId, function(inventory)
			result = InventoryUtils.tryRemove(inventory, targetItem, amount)
			if not result.success then
				log:warn("Failed to remove item:", targetItem.itemType, result.action)
				return false
			end
			return true
		end)

		if not mutated or not result.success or not result.resultItem then
			return false
		end

		self:broadcastInventoryDelta(userId, result.action, result.resultItem)
		return true
	end,

	--[=[
		Removes multiple items from a player's inventory in a single mutation.
		This is a BEST-EFFORT function: it skips items the player doesn't have or has insufficient quantity of.
		If you need All-or-Nothing guarantees, use PlayerDataService:transaction() instead.

		@param userId number -- The user ID to remove items from
		@param requests {RemoveItemRequest} -- Array of items and amounts to remove
		@return boolean -- True if any item was successfully removed, false otherwise
	]=]
	removeItems = function(self, userId, requests)
		assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
		assert(type(requests) == "table", `requests must be a table, got {type(requests)}`)
		if #requests == 0 then
			return true
		end

		local removed: { PlayerDataTypes.InventoryItem } = {}
		local updated: { PlayerDataTypes.InventoryItem } = {}

		local mutated = self:_mutateInventory(userId, function(inventory)
			local didMutate = false
			for _, request in requests do
				assert(type(request.item) == "table", `each request must have an item table, got {type(request.item)}`)
				assert(
					type(request.amount) == "number" and request.amount > 0,
					`each request must have a positive amount, got {type(request.amount)}: {request.amount}`
				)

				local result = InventoryUtils.tryRemove(inventory, request.item, request.amount)
				if not result.success then
					log:warn("Failed to remove item in batch:", request.item.itemType, result.action)
					continue
				end

				didMutate = true
				if result.resultItem then
					if result.action == "remove" then
						table.insert(removed, result.resultItem)
					else
						table.insert(updated, result.resultItem)
					end
				end
			end
			return didMutate
		end)

		if not mutated then
			return false
		end

		self:broadcastInventoryBatchDelta(userId, {}, removed, updated)
		return true
	end,

	--[=[
		Returns the current state of the service for debugging.
		@return { [string]: any } -- Service state
	]=]
	getState = function(_self)
		return {
			note = "Inventory data is stored in PlayerDataServiceServer profiles. Use PlayerDataServiceServer:getState() to inspect.",
		}
	end,
}

return InventoryServiceServer
