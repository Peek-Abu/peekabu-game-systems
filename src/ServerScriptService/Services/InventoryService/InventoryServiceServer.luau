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

local InventoryServiceServer = {}
InventoryServiceServer.dependencies = { "PlayerDataServiceServer" } :: { string }

InventoryServiceServer.MAX_INVENTORY_SIZE = 100

--[=[
	Broadcasts inventory changes to the specified player.
	@param userId number -- The user ID of the player
	@param action string -- The action type ("add", "remove", or "update")
	@param item PlayerDataTypes.InventoryItem -- The item that was changed
]=]
function InventoryServiceServer:broadcastInventoryDelta(
	userId: number,
	action: string,
	item: PlayerDataTypes.InventoryItem
)
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
end

--[=[
	Broadcasts batch inventory changes to the specified player.
	@param userId number -- The user ID of the player
	@param added {PlayerDataTypes.InventoryItem} -- Items that were added
	@param removed {PlayerDataTypes.InventoryItem} -- Items that were removed
	@param updated {PlayerDataTypes.InventoryItem} -- Items that were updated (quantity changed)
]=]
function InventoryServiceServer:broadcastInventoryBatchDelta(
	userId: number,
	added: { PlayerDataTypes.InventoryItem },
	removed: { PlayerDataTypes.InventoryItem },
	updated: { PlayerDataTypes.InventoryItem }
)
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
end

--[=[
	Gets the inventory for a specified user.
	@param userId number -- The user ID to get inventory for
	@return {PlayerDataTypes.InventoryItem} -- Array of inventory items
]=]
function InventoryServiceServer:getInventory(userId: number): { PlayerDataTypes.InventoryItem }
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)

	local profile = PlayerDataService:getProfile(userId)
	return profile and profile.inventory or {}
end

--[=[
	Checks if a player has a specific item in their inventory.
	@param userId number -- The user ID to check
	@param targetItem PlayerDataTypes.InventoryItem -- The item to check for
	@param amount number? -- Optional amount required (defaults to 1)
	@return boolean -- True if the player has the item (and quantity), false otherwise
]=]
function InventoryServiceServer:hasItem(
	userId: number,
	targetItem: PlayerDataTypes.InventoryItem,
	amount: number?
): boolean
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
end

--[=[
	Adds an item to a player's inventory.
	@param userId number -- The user ID to add item to
	@param item PlayerDataTypes.InventoryItem -- The item to add
	@return boolean -- True if the item was successfully added, false otherwise
]=]
function InventoryServiceServer:addItem(userId: number, item: PlayerDataTypes.InventoryItem): boolean
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
	assert(type(item) == "table", `item must be a table, got {type(item)}`)
	assert(item.itemType, `item must have an itemType field`)

	local result: InventoryUtils.AddResult

	local mutated = PlayerDataService:mutate(userId, "inventory", function(inventory: { PlayerDataTypes.InventoryItem })
		-- Check bounds before trying to add new stack
		local idx = InventoryUtils.findMatchingItemIndex(inventory, item)
		if not idx and #inventory >= InventoryServiceServer.MAX_INVENTORY_SIZE then
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
end

--[=[
	Adds multiple items to a player's inventory in a single mutation.
	This is a BEST-EFFORT function: it skips invalid items and processes the rest.
	If you need All-or-Nothing guarantees, use PlayerDataService:transaction() instead.

	@param userId number -- The user ID to add items to
	@param items {PlayerDataTypes.InventoryItem} -- The items to add
	@return boolean -- True if any item was successfully added, false otherwise
]=]
function InventoryServiceServer:addItems(userId: number, items: { PlayerDataTypes.InventoryItem }): boolean
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
	assert(type(items) == "table", `items must be a table, got {type(items)}`)
	if #items == 0 then
		return true
	end

	local added: { PlayerDataTypes.InventoryItem } = {}
	local updated: { PlayerDataTypes.InventoryItem } = {}

	local mutated = PlayerDataService:mutate(userId, "inventory", function(inventory: { PlayerDataTypes.InventoryItem })
		local didMutate = false
		for _, item in items do
			assert(item.itemType, `each item must have an itemType field`)
			
			local idx = InventoryUtils.findMatchingItemIndex(inventory, item)
			if not idx and #inventory >= InventoryServiceServer.MAX_INVENTORY_SIZE then
				log:warn(`Player {userId} hit max inventory size. Skipping remaining items in batch.`)
				break
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
end

--[=[
	Removes a quantity of an item from a player's inventory.
	Uses InventoryUtils.tryRemove for all quantity and unique-item logic.

	@param userId number -- The user ID to remove item from
	@param targetItem PlayerDataTypes.InventoryItem -- The item to remove
	@param amount number -- The quantity to remove
	@return boolean -- True if the item was successfully removed, false otherwise
]=]
function InventoryServiceServer:removeItem(
	userId: number,
	targetItem: PlayerDataTypes.InventoryItem,
	amount: number
): boolean
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
	assert(type(targetItem) == "table", `targetItem must be a table, got {type(targetItem)}`)
	assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)

	local result: InventoryUtils.RemoveResult

	local mutated = PlayerDataService:mutate(userId, "inventory", function(inventory: { PlayerDataTypes.InventoryItem })
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
end

export type RemoveItemRequest = {
	item: PlayerDataTypes.InventoryItem,
	amount: number,
}

--[=[
	Removes multiple items from a player's inventory in a single mutation.
	This is a BEST-EFFORT function: it skips items the player doesn't have or has insufficient quantity of.
	If you need All-or-Nothing guarantees, use PlayerDataService:transaction() instead.

	@param userId number -- The user ID to remove items from
	@param requests {RemoveItemRequest} -- Array of items and amounts to remove
	@return boolean -- True if any item was successfully removed, false otherwise
]=]
function InventoryServiceServer:removeItems(userId: number, requests: { RemoveItemRequest }): boolean
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
	assert(type(requests) == "table", `requests must be a table, got {type(requests)}`)
	if #requests == 0 then
		return true
	end

	local removed: { PlayerDataTypes.InventoryItem } = {}
	local updated: { PlayerDataTypes.InventoryItem } = {}

	local mutated = PlayerDataService:mutate(userId, "inventory", function(inventory: { PlayerDataTypes.InventoryItem })
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
end

--[=[
	Returns the current state of the service for debugging.
	@return { [string]: any } -- Service state
]=]
function InventoryServiceServer:getState(): { [string]: any }
	return {
		note = "Inventory data is stored in PlayerDataServiceServer profiles. Use PlayerDataServiceServer:getState() to inspect.",
	}
end

type InventoryServiceServer = typeof(InventoryServiceServer)

return InventoryServiceServer :: InventoryServiceServer
