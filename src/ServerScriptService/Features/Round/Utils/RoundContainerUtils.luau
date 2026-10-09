--!strict
--[=[
	RoundContainerUtils: pure operations on a run-scoped container (a `{ InventoryEntry }` array that is
	never saved — a team stash or a run bag). They reuse the saved inventory's own rules: stacks are placed
	by `InventoryPlacementUtils` and every result is checked by `InventoryContainerRules.checkEntryShapes`
	under a flat entry capacity, so a run container holds exactly the shapes (and registered items) the
	inventory does.

	Every operation works on a copy and only writes back into `items` when the whole result is valid, so a
	refusal leaves the container untouched.

	@class RoundContainerUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local InventoryContainerRules = require(ReplicatedStorage.Shared.Features.Inventory.Rules.InventoryContainerRules)
local InventoryPlacementUtils = require(ReplicatedStorage.Shared.Features.Inventory.Utils.InventoryPlacementUtils)
local InventoryUtils = require(ReplicatedStorage.Shared.Features.Inventory.Utils.InventoryUtils)

type InventoryEntry = PlayerDataTypes.InventoryEntry

local LABEL = "run container"

-- Validates `candidate` and, when it holds, replaces `items`' contents with it.
local function commit(items: { InventoryEntry }, candidate: { InventoryEntry }, capacity: number): (boolean, string?)
	if #candidate > capacity then
		return false, `{LABEL} is full ({capacity} entries)`
	end
	local ok, reason = InventoryContainerRules.checkEntryShapes(candidate, LABEL)
	if not ok then
		return false, reason
	end
	table.clear(items)
	table.move(candidate, 1, #candidate, 1, items)
	return true, nil
end

local function isCount(count: number): boolean
	return count >= 1 and count == math.floor(count)
end

local RoundContainerUtils = {}

--[=[
	The total quantity of a stackable `itemType`, or the number of entries of a unique one.
]=]
function RoundContainerUtils.countOf(items: { InventoryEntry }, itemType: string): number
	return InventoryUtils.countOf({ items = items }, itemType)
end

--[=[
	Adds `count` of a stackable item: tops up existing stacks, then opens new ones within `capacity`.
]=]
function RoundContainerUtils.addStack(
	items: { InventoryEntry },
	itemType: string,
	count: number,
	capacity: number
): (boolean, string?)
	if not isCount(count) then
		return false, "count must be a whole number of at least 1"
	end
	local definition = ItemRegistry.get(itemType)
	if definition == nil then
		return false, `unregistered item "{itemType}"`
	end
	if not ItemRegistry.isStackable(itemType) then
		return false, `"{itemType}" is not stackable`
	end
	local stackMax, maxStacks = InventoryContainerRules.stackLimitsOf(definition)
	local plan = InventoryPlacementUtils.planStackPlacement(
		items,
		itemType,
		count,
		stackMax,
		maxStacks,
		definition.kind,
		function(current, _kind, newEntries)
			if #current + newEntries > capacity then
				return false, `{LABEL} is full ({capacity} entries)`
			end
			return true, nil
		end
	)
	if not plan.ok then
		return false, plan.reason
	end
	local candidate = table.clone(items)
	local updates = plan.updates
	if updates ~= nil then
		for index, quantity in updates do
			candidate[index] = { itemType = itemType, quantity = quantity }
		end
	end
	local newStacks = plan.newStacks
	if newStacks ~= nil then
		for _, quantity in newStacks do
			table.insert(candidate, { itemType = itemType, quantity = quantity })
		end
	end
	return commit(items, candidate, capacity)
end

--[=[
	Adds one unique item with a caller-chosen `uid` (unique within the container) and optional attrs.
]=]
function RoundContainerUtils.addUnique(
	items: { InventoryEntry },
	itemType: string,
	uid: string,
	attrs: { [string]: PlayerDataTypes.AttrValue }?,
	capacity: number
): (boolean, string?)
	if ItemRegistry.get(itemType) == nil then
		return false, `unregistered item "{itemType}"`
	end
	if ItemRegistry.isStackable(itemType) then
		return false, `"{itemType}" is stackable; use addStack`
	end
	local candidate = table.clone(items)
	local entry: PlayerDataTypes.UniqueEntry = {
		itemType = itemType,
		uid = uid,
		attrs = if attrs ~= nil then table.clone(attrs) else nil,
	}
	table.insert(candidate, entry)
	return commit(items, candidate, capacity)
end

--[=[
	Removes `count` of a stackable item, from the last stacks first. Refuses (changing nothing) when the
	container holds less.
]=]
function RoundContainerUtils.removeStack(items: { InventoryEntry }, itemType: string, count: number): (boolean, string?)
	if not isCount(count) then
		return false, "count must be a whole number of at least 1"
	end
	if not ItemRegistry.isStackable(itemType) then
		return false, `"{itemType}" is not stackable`
	end
	if RoundContainerUtils.countOf(items, itemType) < count then
		return false, `not enough "{itemType}"`
	end
	local candidate = table.clone(items)
	local remaining = count
	for index = #candidate, 1, -1 do
		local entry = candidate[index]
		if remaining > 0 and entry.itemType == itemType then
			-- Stackable itemType (checked above), so the entry is a StackEntry.
			local stack = entry :: PlayerDataTypes.StackEntry -- see the isStackable check above
			local take = math.min(stack.quantity, remaining)
			remaining -= take
			if take == stack.quantity then
				table.remove(candidate, index)
			else
				candidate[index] = { itemType = itemType, quantity = stack.quantity - take }
			end
		end
	end
	table.clear(items)
	table.move(candidate, 1, #candidate, 1, items)
	return true, nil
end

--[=[
	Removes the unique entry with `uid`. False when there is none.
]=]
function RoundContainerUtils.removeUnique(items: { InventoryEntry }, uid: string): boolean
	local index = InventoryUtils.findByUid({ items = items }, uid)
	if index == nil then
		return false
	end
	table.remove(items, index)
	return true
end

return RoundContainerUtils
