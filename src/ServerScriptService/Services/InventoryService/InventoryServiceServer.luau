--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Guard = require(ReplicatedStorage.Shared.Modules.Guard)
local InventoryUtils = require(ReplicatedStorage.Shared.Modules.Utils.InventoryUtils)
local ItemDefinitions = require(ReplicatedStorage.Shared.Modules.ItemDefinitions)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local SliceOwner = require(ServerScriptService.Modules.SliceOwner)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)

-- Max stacks an inventory may hold. A module-local const (not just the service field) so the data-layer
-- validator below and the MAX_INVENTORY_SIZE interface field share one source of truth — the validator
-- is built at module load, before the service table literal exists.
local MAX_INVENTORY_SIZE = 100

-- The inventory invariant, enforced by the DATA LAYER on every write (see SliceOwner's `validate`).
-- The service methods below already guard these (bounds via addItem, item validity via tryAdd), but
-- registering the FULL invariant here makes it hold for ANY path into the slice — including a raw
-- `PlayerDataService:transaction()` op (e.g. a trade) that never goes through addItem. Both halves
-- matter: without the size check the cap was a service-method convention, and without the per-item
-- checks a raw op could persist (and replicate to the client) an unregistered itemType or a
-- non-positive stack. Runs after a mutator, inside the no-yield region, so it must stay
-- pure/synchronous.
local function validateInventory(inventory: { PlayerDataTypes.InventoryItem }): (boolean, string?)
	if #inventory > MAX_INVENTORY_SIZE then
		return false, `inventory size {#inventory} exceeds MAX_INVENTORY_SIZE ({MAX_INVENTORY_SIZE})`
	end
	for index, item in inventory do
		-- Mirror what tryAdd asserts on the service path: entry shape, a registered itemType, a
		-- positive numeric quantity (nil means 1), and instanceId a string when present.
		if type(item) ~= "table" then
			return false, `inventory[{index}] must be a table, got {type(item)}`
		end
		if type(item.itemType) ~= "string" or not ItemDefinitions.isValidItemType(item.itemType) then
			return false, `inventory[{index}] has unregistered itemType "{tostring(item.itemType)}"`
		end
		if item.quantity ~= nil and (type(item.quantity) ~= "number" or item.quantity <= 0) then
			return false, `inventory[{index}] ("{item.itemType}") has non-positive quantity {tostring(item.quantity)}`
		end
		if item.instanceId ~= nil and type(item.instanceId) ~= "string" then
			return false, `inventory[{index}] ("{item.itemType}") has a non-string instanceId`
		end
	end
	return true
end

-- Registers the "inventory" profile slice and returns typed read/mutate access. This is the shared
-- slice-owner scaffolding (see SliceOwner) — the inventory VALUE type flows from the reader below, so
-- `inventorySlice.get` returns `{ InventoryItem }?` and every `inventorySlice.mutate` mutator argument
-- is typed `{ InventoryItem }`, with no casts. Only inventory's DOMAIN logic (stacking, batch, caps)
-- lives in this file.
local inventorySlice = SliceOwner.register("inventory", {}, function(profile)
	return profile.inventory
end, validateInventory)

local log = Logger.new("InventoryServiceServer")

export type RemoveItemRequest = {
	item: PlayerDataTypes.InventoryItem,
	amount: number,
}

--[=[
	Structured outcome of the best-effort batch operations (addItems/removeItems), returned alongside
	the boolean so callers can tell "all applied" from "some skipped" without reaching for a full
	transaction(). `applied + skipped == total`; the boolean return is `applied > 0`.
]=]
export type BatchResult = {
	applied: number,
	skipped: number,
	total: number,
}

--[=[
	Public interface of the service — the SINGLE place method/field types are declared.

	The module below is one annotated table literal. Annotating the literal makes Luau push each
	signature from this interface DOWN into the matching method body, so the methods need NO inline
	type annotations. Types live in exactly one place, and there are zero casts.

	Reads/writes go through `inventorySlice` (SliceOwner) rather than PlayerDataService directly: the
	slice owns the "inventory" path string and the type, so there is no stringly-typed path to typo and
	the mutator's `inventory` argument is typed without an inline annotation.

	Writes reach the owning client through the reactive path only: a mutation updates the profile,
	`PlayerDataServiceServer:mutate` mirrors the slice into `ServerStore`, and charm-sync ships the
	delta. There is no per-write broadcast packet.
]=]
export type InventoryServiceServer = {
	dependencies: { string },
	MAX_INVENTORY_SIZE: number,

	getInventory: (self: InventoryServiceServer, userId: number) -> { PlayerDataTypes.InventoryItem },
	hasItem: (
		self: InventoryServiceServer,
		userId: number,
		targetItem: PlayerDataTypes.InventoryItem,
		amount: number?
	) -> boolean,
	addItem: (self: InventoryServiceServer, userId: number, item: PlayerDataTypes.InventoryItem) -> boolean,
	addItems: (
		self: InventoryServiceServer,
		userId: number,
		items: { PlayerDataTypes.InventoryItem }
	) -> (boolean, BatchResult),
	removeItem: (
		self: InventoryServiceServer,
		userId: number,
		targetItem: PlayerDataTypes.InventoryItem,
		amount: number
	) -> boolean,
	removeItems: (
		self: InventoryServiceServer,
		userId: number,
		requests: { RemoveItemRequest }
	) -> (boolean, BatchResult),
	inventoryOp: (
		self: InventoryServiceServer,
		userId: number,
		mutator: (inventory: { PlayerDataTypes.InventoryItem }) -> boolean
	) -> PlayerDataService.TransactionOperation,
	getState: (self: InventoryServiceServer) -> { [string]: any },
}

local InventoryServiceServer: InventoryServiceServer = {
	dependencies = { "PlayerDataServiceServer" },

	MAX_INVENTORY_SIZE = MAX_INVENTORY_SIZE,

	--[=[
		Gets the inventory for a specified user.
		@param userId number -- The user ID to get inventory for
		@return {PlayerDataTypes.InventoryItem} -- Array of inventory items
	]=]
	getInventory = function(_self, userId)
		return inventorySlice.get(userId) or {}
	end,

	--[=[
		Checks if a player has a specific item in their inventory.
		@param userId number -- The user ID to check
		@param targetItem PlayerDataTypes.InventoryItem -- The item to check for
		@param amount number? -- Optional amount required (defaults to 1)
		@return boolean -- True if the player has the item (and quantity), false otherwise
	]=]
	hasItem = function(self, userId, targetItem, amount)
		Guard.userId(userId)
		assert(type(targetItem) == "table", `targetItem must be a table, got {type(targetItem)}`)
		if amount ~= nil then
			Guard.positiveAmount(amount)
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
		Adds an item to a player's inventory.
		@param userId number -- The user ID to add item to
		@param item PlayerDataTypes.InventoryItem -- The item to add
		@return boolean -- True if the item was successfully added, false otherwise
	]=]
	addItem = function(self, userId, item)
		Guard.userId(userId)
		assert(type(item) == "table", `item must be a table, got {type(item)}`)
		assert(item.itemType, `item must have an itemType field`)
		-- Guard the quantity at the single-item choke point (consistent with addCurrency's
		-- positive-amount guard), so a caller like the `giveitem` command can't write a negative or
		-- zero stack. `nil` is allowed and means 1. tryAdd rejects it too (defense in depth).
		if item.quantity ~= nil then
			Guard.positiveAmount(item.quantity)
		end

		return inventorySlice.mutate(userId, function(inventory)
			-- Check bounds before trying to add a new stack
			local idx = InventoryUtils.findMatchingItemIndex(inventory, item)
			if not idx and #inventory >= self.MAX_INVENTORY_SIZE then
				log:warn(`Player {userId} exceeded max inventory size`)
				return false
			end

			local result = InventoryUtils.tryAdd(inventory, item)
			if not result.success then
				log:warn("Attempted to add a unique item that already exists:", item.itemType, item.instanceId)
				return false
			end
			return true
		end)
	end,

	--[=[
		Adds multiple items to a player's inventory in a single mutation.
		This is a BEST-EFFORT function: it skips invalid items and processes the rest.
		If you need All-or-Nothing guarantees, use PlayerDataService:transaction() instead.

		@param userId number -- The user ID to add items to
		@param items {PlayerDataTypes.InventoryItem} -- The items to add
		@return boolean -- True if any item was successfully added, false otherwise
		@return BatchResult -- { applied, skipped, total } so callers can detect partial application
	]=]
	addItems = function(self, userId, items)
		Guard.userId(userId)
		assert(type(items) == "table", `items must be a table, got {type(items)}`)
		local total = #items
		if total == 0 then
			return true, { applied = 0, skipped = 0, total = 0 }
		end

		-- Counted in the outer scope so the tally survives even when mutate() reports no change
		-- (didMutate == false) or the profile isn't loaded (mutator never runs, applied stays 0).
		local applied = 0
		inventorySlice.mutate(userId, function(inventory)
			local didMutate = false
			for _, item in items do
				-- Best-effort contract: SKIP invalid entries and keep going, never throw. Screen the
				-- entry here (type, itemType presence + validity, positive quantity) so the mutator
				-- stays total — a raised assert would abort the whole batch AND, because mutate()
				-- swallows the error before mirroring, leave already-applied in-place edits unsynced
				-- to the client. tryAdd still asserts these on the single-item path.
				if type(item) ~= "table" or not item.itemType or not ItemDefinitions.isValidItemType(item.itemType) then
					log:warn(
						"Skipping invalid item in addItems batch:",
						type(item) == "table" and item.itemType or item
					)
					continue
				end
				if item.quantity ~= nil and (type(item.quantity) ~= "number" or item.quantity <= 0) then
					log:warn("Skipping item with non-positive quantity in addItems batch:", item.itemType)
					continue
				end

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
				applied += 1
				didMutate = true
			end
			return didMutate
		end)

		return applied > 0, { applied = applied, skipped = total - applied, total = total }
	end,

	--[=[
		Removes a quantity of an item from a player's inventory.
		Uses InventoryUtils.tryRemove for all quantity and unique-item logic.

		@param userId number -- The user ID to remove item from
		@param targetItem PlayerDataTypes.InventoryItem -- The item to remove
		@param amount number -- The quantity to remove
		@return boolean -- True if the item was successfully removed, false otherwise
	]=]
	removeItem = function(_self, userId, targetItem, amount)
		Guard.userId(userId)
		assert(type(targetItem) == "table", `targetItem must be a table, got {type(targetItem)}`)
		Guard.positiveAmount(amount)

		return inventorySlice.mutate(userId, function(inventory)
			local result = InventoryUtils.tryRemove(inventory, targetItem, amount)
			if not result.success then
				log:warn("Failed to remove item:", targetItem.itemType, result.action)
				return false
			end
			return true
		end)
	end,

	--[=[
		Removes multiple items from a player's inventory in a single mutation.
		This is a BEST-EFFORT function: it skips items the player doesn't have or has insufficient quantity of.
		If you need All-or-Nothing guarantees, use PlayerDataService:transaction() instead.

		@param userId number -- The user ID to remove items from
		@param requests {RemoveItemRequest} -- Array of items and amounts to remove
		@return boolean -- True if any item was successfully removed, false otherwise
		@return BatchResult -- { applied, skipped, total } so callers can detect partial application
	]=]
	removeItems = function(_self, userId, requests)
		Guard.userId(userId)
		assert(type(requests) == "table", `requests must be a table, got {type(requests)}`)
		local total = #requests
		if total == 0 then
			return true, { applied = 0, skipped = 0, total = 0 }
		end

		-- Counted in the outer scope (see addItems) so the tally is accurate regardless of mutate()'s
		-- didMutate return or an unloaded profile.
		local applied = 0
		inventorySlice.mutate(userId, function(inventory)
			local didMutate = false
			for _, request in requests do
				-- Best-effort: SKIP malformed requests instead of asserting (a throw would abort the
				-- batch and leave earlier in-place removals unsynced — see addItems). Screen the SAME
				-- fields tryRemove would assert on (item table, itemType presence + validity, positive
				-- amount) so the mutator stays total. tryRemove still asserts these on the single-item
				-- removeItem path.
				if type(request) ~= "table" or type(request.item) ~= "table" then
					log:warn("Skipping malformed request in removeItems batch")
					continue
				end
				local reqItem = request.item
				if not reqItem.itemType or not ItemDefinitions.isValidItemType(reqItem.itemType) then
					log:warn("Skipping request with invalid itemType in removeItems batch:", reqItem.itemType)
					continue
				end
				if type(request.amount) ~= "number" or request.amount <= 0 then
					log:warn("Skipping request with non-positive amount in removeItems batch:", reqItem.itemType)
					continue
				end

				local result = InventoryUtils.tryRemove(inventory, request.item, request.amount)
				if not result.success then
					log:warn("Failed to remove item in batch:", request.item.itemType, result.action)
					continue
				end
				applied += 1
				didMutate = true
			end
			return didMutate
		end)

		return applied > 0, { applied = applied, skipped = total - applied, total = total }
	end,

	--[=[
		Mints a typed TransactionOperation over the inventory slice, for composing multi-slice /
		multi-player atomic writes via `PlayerDataService:transaction()` — e.g. a trade pairing this
		with `CurrencyService:currencyOp`. The mutator's `inventory` param is fully typed. Pure
		packaging: nothing runs (and no validation beyond userId) until transaction() executes.
		@param userId number -- The user ID the op targets
		@param mutator (inventory: { InventoryItem }) -> boolean -- Typed mutator; return false to abort the transaction
		@return PlayerDataService.TransactionOperation
	]=]
	inventoryOp = function(_self, userId, mutator)
		return inventorySlice.op(userId, mutator)
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
