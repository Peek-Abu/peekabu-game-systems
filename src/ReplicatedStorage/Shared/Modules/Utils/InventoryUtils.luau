--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryUtils = {}

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local ItemDefinitions = require(ReplicatedStorage.Shared.Modules.ItemDefinitions)
local Guard = require(ReplicatedStorage.Shared.Modules.Guard)

--[=[
	Expands an inventory item with its definition data.
	@param item PlayerDataTypes.InventoryItem -- The item to expand
	@return PlayerDataTypes.ExpandedInventoryItem -- The expanded item with definition data merged
]=]
function InventoryUtils.expandItem(item: PlayerDataTypes.InventoryItem): PlayerDataTypes.ExpandedInventoryItem
	assert(type(item) == "table", `item must be a table, got {type(item)}`)
	assert(item.itemType, `item must have an itemType field`)

	local def = ItemDefinitions.get(item.itemType)
	if not def then
		warn("No definition for itemType:", item.itemType)
		-- Unknown type: fill placeholder definition fields so the result is still a complete
		-- ExpandedInventoryItem (previously this returned a bare item with nil name/rarity/icon).
		return {
			itemType = item.itemType,
			quantity = item.quantity,
			instanceId = item.instanceId,
			name = item.itemType,
			rarity = "Unknown",
			icon = "",
		}
	end

	-- Combine the item's stored fields with its definition's display fields.
	return {
		itemType = item.itemType,
		quantity = item.quantity,
		instanceId = item.instanceId,
		name = def.name,
		rarity = def.rarity,
		icon = def.icon,
	}
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

	Matching is instanceId-aware so a stackable operation never collides with a unique instance of
	the same itemType:
	- A query WITH an instanceId matches only that exact unique instance.
	- A query WITHOUT an instanceId matches only a stackable entry (one that also has no
	  instanceId), never a unique instance. So a stackable "potion" and a unique "potion" instance
	  can coexist: adding stackable "potion" finds the stack (or none), and removing "potion" by
	  type targets the stack, leaving the unique untouched.

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
			if item.instanceId then
				-- Unique query: match the exact instance only.
				if it.instanceId == item.instanceId then
					return i
				end
			elseif it.instanceId == nil then
				-- Stackable query: match the stackable entry, never a unique instance of this type.
				return i
			end
		end
	end
	return nil
end

export type AddResult = {
	success: boolean,
	action: "add" | "update" | "rejected",
	-- An independent SNAPSHOT (copy) of the affected stack, never a live reference into the
	-- inventory: `"add"` -> the newly stored stack; `"update"` -> the stack at its new quantity;
	-- `"rejected"` -> nil. Safe to keep/broadcast without aliasing the stored entry.
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

	-- A non-positive (or non-number) quantity is never a valid add — stacking it would produce a
	-- negative or junk-zero entry. Reject it (rather than assert) so callers get a uniform, total
	-- contract: batch callers skip it, single callers get a clean `success = false`, and a
	-- transaction op-mutator that reaches here directly can't corrupt a stack. `nil` means "1".
	if item.quantity ~= nil and (type(item.quantity) ~= "number" or item.quantity <= 0) then
		return { success = false, action = "rejected", resultItem = nil }
	end

	local idx = InventoryUtils.findMatchingItemIndex(inventory, item)

	if idx then
		local existing = inventory[idx]

		-- Reject duplicate unique items. findMatchingItemIndex only returns an instanced entry when
		-- the query carried the same instanceId, so this is genuinely the same unique item.
		if existing.instanceId then
			return {
				success = false,
				action = "rejected",
				resultItem = nil,
			}
		end

		-- Stack quantities.
		existing.quantity = (existing.quantity or 1) + (item.quantity or 1)
		return {
			success = true,
			action = "update",
			-- Snapshot at the new quantity — never the live entry.
			resultItem = table.clone(existing),
		}
	else
		-- New item: store an independent copy so a caller that later mutates or reuses `item`
		-- (e.g. a decoded network payload it still holds a reference to) can't retroactively
		-- change what now lives in the inventory.
		local stored = table.clone(item)
		table.insert(inventory, stored)
		return {
			success = true,
			action = "add",
			resultItem = table.clone(stored),
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
	-- An independent SNAPSHOT (copy) of the affected stack, never a live reference:
	-- `"update"` -> the stack at its remaining quantity; `"remove"` -> a snapshot whose `quantity`
	-- is the amount that LEFT the inventory (not a zero-quantity leftover); `"insufficient"` -> the
	-- matched stack as-is; `"not_found"` -> nil. Safe to keep/broadcast without aliasing.
	resultItem: PlayerDataTypes.InventoryItem?,
}

--[=[
	Attempts to remove a quantity of an item from inventory with a detailed result.

	Unique items (with instanceId): a single physical instance, so a valid removal is
	`amount == 1`, which removes the entry. Requesting `amount > 1` is a caller error
	(there is only ever one) and returns `action = "insufficient"` rather than silently
	removing the one item.
	Stackable items: decrements quantity by `amount`. Removes the entry entirely if
	the resulting quantity reaches 0. Returns `action = "insufficient"` if not enough.

	This is the primary remove API for server-side operations where you need
	quantity handling and a result for broadcasting.

	Use `remove()` for simple full-entry removal (client-side delta application).

	@param inventory {PlayerDataTypes.InventoryItem} -- The inventory to remove from
	@param item PlayerDataTypes.InventoryItem -- The item to find (matched by itemType + instanceId)
	@param amount number -- Quantity to remove (must be 1 for unique items with instanceId)
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
	Guard.positiveAmount(amount)

	local idx = InventoryUtils.findMatchingItemIndex(inventory, item)
	if not idx then
		return { success = false, action = "not_found", resultItem = nil }
	end

	local existing = inventory[idx]

	if existing.instanceId then
		-- Unique item: exactly one instance exists. Asking for more than one can't be
		-- satisfied, so surface it as insufficient instead of silently removing the one.
		if amount > 1 then
			return { success = false, action = "insufficient", resultItem = table.clone(existing) }
		end
		local removed = table.clone(existing)
		table.remove(inventory, idx)
		return { success = true, action = "remove", resultItem = removed }
	end

	-- Stackable item
	local currentQty = existing.quantity or 1
	if currentQty < amount then
		return { success = false, action = "insufficient", resultItem = table.clone(existing) }
	end

	existing.quantity = currentQty - amount
	if existing.quantity <= 0 then
		-- Whole stack removed. Report a snapshot carrying the quantity that LEFT the inventory
		-- (`amount`), not the decremented-to-zero live entry — a broadcast consumer applying this
		-- delta needs "how many were removed", and a zero-quantity item would be misleading.
		local removed = table.clone(existing)
		removed.quantity = amount
		table.remove(inventory, idx)
		return { success = true, action = "remove", resultItem = removed }
	end

	-- Partial removal: snapshot of the stack at its remaining quantity.
	return { success = true, action = "update", resultItem = table.clone(existing) }
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
