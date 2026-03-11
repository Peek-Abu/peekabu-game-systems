--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryUtils = {}

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local ItemDefinitions = require(ReplicatedStorage.Shared.Modules.ItemDefinitions)

--[=[
	Expands an inventory item with its definition data.
	@param item PlayerDataTypes.InventoryItem -- The item to expand
	@return PlayerDataTypes.ExpandedInventoryItem -- The expanded item with definition data merged
]=]
function InventoryUtils.expandItem(item: PlayerDataTypes.InventoryItem): PlayerDataTypes.ExpandedInventoryItem
	assert(type(item) == "table", `item must be a table, got {type(item)}`)
	assert(item.itemType, `item must have an itemType field`)

	local def = ItemDefinitions[item.itemType]
	if not def then
		warn("No definition for itemType:", item.itemType)
		return item -- fallback to basic
	end
	-- Merge DB item page onto ItemDefinition copy (item fields override template)
	local merged = table.clone(def)
	for k, v in pairs(item) do
		merged[k] = v
	end
	return merged :: PlayerDataTypes.ExpandedInventoryItem
end

--[=[
	Expands multiple inventory items with their definition data.
	@param items {PlayerDataTypes.InventoryItem} -- Array of items to expand
	@return {PlayerDataTypes.ExpandedInventoryItem} -- Array of expanded items
]=]
function InventoryUtils.expandAll(items: { PlayerDataTypes.InventoryItem }): { PlayerDataTypes.ExpandedInventoryItem }
	assert(type(items) == "table", `items must be a table, got {type(items)}`)

	local out = {}
	for i, dbItem in ipairs(items) do
		out[i] = InventoryUtils.expandItem(dbItem)
	end
	return out
end

--[=[
	Finds an item in inventory by itemType and optionally instanceId.
	@param inventory {PlayerDataTypes.InventoryItem} -- The inventory to search
	@param item PlayerDataTypes.InventoryItem -- The item to find
	@return number? -- The index of the matching item or nil if not found
]=]
function InventoryUtils.findMatchingItemIndex(
	inventory: { PlayerDataTypes.InventoryItem },
	item: PlayerDataTypes.InventoryItem
): number?
	assert(type(inventory) == "table", `inventory must be a table, got {type(inventory)}`)
	assert(type(item) == "table", `item must be a table, got {type(item)}`)
	assert(item.itemType, `item must have an itemType field`)

	for i, it in inventory do
		if it.itemType == item.itemType then
			-- For unique items, must match both itemType and instanceId
			if item.instanceId then
				if it.instanceId == item.instanceId then
					return i
				end
			else
				return i
			end
		end
	end
	return nil
end

export type AddResult = {
	success: boolean,
	action: "add" | "update" | "rejected",
	resultItem: PlayerDataTypes.InventoryItem?,
}

--[=[
	Attempts to add an item to inventory with detailed result.
	Rejects duplicate unique items (items with instanceId that already exist).
	For stackable items, increases quantity. For new items, inserts.

	Use this when you need the result (server-side for broadcasting).
	Use `add()` when you just want to apply the change (client-side).

	@param inventory {PlayerDataTypes.InventoryItem} -- The inventory to add to
	@param item PlayerDataTypes.InventoryItem -- The item to add
	@return AddResult -- Result with success, action type, and resulting item
]=]
function InventoryUtils.tryAdd(
	inventory: { PlayerDataTypes.InventoryItem },
	item: PlayerDataTypes.InventoryItem
): AddResult
	assert(type(item) == "table", `item must be a table, got {type(item)}`)
	assert(item.itemType, `item must have an itemType field`)
	assert(ItemDefinitions.isValidItemType(item.itemType), `invalid item type: "{item.itemType}"`)

	local idx = InventoryUtils.findMatchingItemIndex(inventory, item)

	if idx then
		local existing = inventory[idx]

		-- Reject duplicate unique items
		if existing.instanceId then
			return {
				success = false,
				action = "rejected",
				resultItem = nil,
			}
		end

		-- Stack quantities
		existing.quantity = (existing.quantity or 1) + (item.quantity or 1)
		return {
			success = true,
			action = "update",
			resultItem = existing,
		}
	else
		-- New item
		table.insert(inventory, item)
		return {
			success = true,
			action = "add",
			resultItem = item,
		}
	end
end

--[=[
	Adds an item to inventory, ignoring the result.
	Wrapper around tryAdd() for cases where you don't need the result.

	Typical use: Client-side applying server-authoritative updates.

	@param inventory {PlayerDataTypes.InventoryItem} -- The inventory to add to
	@param item PlayerDataTypes.InventoryItem -- The item to add
]=]
function InventoryUtils.add(inventory: { PlayerDataTypes.InventoryItem }, item: PlayerDataTypes.InventoryItem)
	InventoryUtils.tryAdd(inventory, item)
end

export type RemoveResult = {
	success: boolean,
	action: "remove" | "update" | "not_found" | "insufficient",
	resultItem: PlayerDataTypes.InventoryItem?,
}

--[=[
	Attempts to remove a quantity of an item from inventory with a detailed result.

	Unique items (with instanceId): always removed outright — `amount` is ignored.
	Stackable items: decrements quantity by `amount`. Removes the entry entirely if
	the resulting quantity reaches 0. Returns `action = "insufficient"` if not enough.

	This is the primary remove API for server-side operations where you need
	quantity handling and a result for broadcasting.

	Use `remove()` for simple full-entry removal (client-side delta application).

	@param inventory {PlayerDataTypes.InventoryItem} -- The inventory to remove from
	@param item PlayerDataTypes.InventoryItem -- The item to find (matched by itemType + instanceId)
	@param amount number -- Quantity to remove (ignored for unique items with instanceId)
	@return RemoveResult -- Result with success, action type, and the affected item snapshot
]=]
function InventoryUtils.tryRemove(
	inventory: { PlayerDataTypes.InventoryItem },
	item: PlayerDataTypes.InventoryItem,
	amount: number
): RemoveResult
	assert(type(item) == "table", `item must be a table, got {type(item)}`)
	assert(item.itemType, `item must have an itemType field`)
	assert(ItemDefinitions.isValidItemType(item.itemType), `invalid item type: "{item.itemType}"`)
	assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)

	local idx = InventoryUtils.findMatchingItemIndex(inventory, item)
	if not idx then
		return { success = false, action = "not_found", resultItem = nil }
	end

	local existing = inventory[idx]

	if existing.instanceId then
		-- Unique item: always remove the full entry regardless of amount
		table.remove(inventory, idx)
		return { success = true, action = "remove", resultItem = existing }
	end

	-- Stackable item
	local currentQty = existing.quantity or 1
	if currentQty < amount then
		return { success = false, action = "insufficient", resultItem = existing }
	end

	existing.quantity = currentQty - amount
	if existing.quantity <= 0 then
		table.remove(inventory, idx)
		return { success = true, action = "remove", resultItem = existing }
	end

	return { success = true, action = "update", resultItem = existing }
end

--[=[
	Removes an item entry from inventory entirely (no quantity partial-removal logic).

	Typical use: Client-side applying server-authoritative "remove" action deltas,
	where the server has already resolved quantities and sent a full removal signal.

	For server-side operations where you need quantity handling and a structured result,
	use `tryRemove()` instead.

	@param inventory {PlayerDataTypes.InventoryItem} -- The inventory to remove from
	@param item PlayerDataTypes.InventoryItem -- The item to remove
]=]
function InventoryUtils.remove(inventory: { PlayerDataTypes.InventoryItem }, item: PlayerDataTypes.InventoryItem)
	assert(type(inventory) == "table", `inventory must be a table, got {type(inventory)}`)
	assert(type(item) == "table", `item must be a table, got {type(item)}`)
	assert(item.itemType, `item must have an itemType field`)

	local idx = InventoryUtils.findMatchingItemIndex(inventory, item)
	if idx then
		table.remove(inventory, idx)
	end
end

return InventoryUtils
