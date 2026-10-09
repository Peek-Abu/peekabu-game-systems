--!strict
--[=[
	InventoryContainerRules: pure per-entry shape checking for a `{ InventoryEntry }` array, shared by every
	container that holds the same entry union (the Inventory, and any second container a game adds — a
	bank, a pet pen, a run bag, a team stash).

	Extracted from `InventoryServiceServer.validateInventory` so a second container reuses the exact same
	shape rules instead of re-deriving them. It deliberately does NOT decide capacity: the
	per-entry `maxStacks` bound IS enforced here (it is intrinsic to the item definition, not a container
	policy), but the per-KIND / flat-total entry cap is the caller's own policy, applied over the
	`kindCounts` this returns. `label` names the container in rejection messages ("inventory.items[3]…"
	vs "stash.items[3]…").

	@class InventoryContainerRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local InventoryUtils = require(ReplicatedStorage.Shared.Features.Inventory.Utils.InventoryUtils)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

local InventoryContainerRules = {}

--[=[
	The per-container counts a caller applies its own cap policy over.
	@interface ShapeCheckResult
	.kindCounts { [string]: number } -- entries per registered kind (a stack or a unique counts once)
	.stackCountsByType { [string]: number } -- STACK-entry count per itemType (already checked vs maxStacks here)
]=]
export type ShapeCheckResult = {
	kindCounts: { [string]: number },
	stackCountsByType: { [string]: number },
}

--[=[
	A stackable item's definition always declares `stackMax` (that declaration is what makes it
	stackable); `maxStacks` is optional. Throws if called on a non-stackable definition — callers must
	check `ItemRegistry.isStackable` first.
	@param definition PlayerDataTypes.ItemDefinition
	@return number -- stackMax
	@return number? -- maxStacks
]=]
function InventoryContainerRules.stackLimitsOf(definition: PlayerDataTypes.ItemDefinition): (number, number?)
	local stackMax = definition.stackMax
	assert(stackMax ~= nil, `stackLimitsOf called on non-stackable item "{definition.name}"`)
	return stackMax, definition.maxStacks
end

--[=[
	Validates the shape of every entry in `items` (registration, stack-vs-unique shape, per-instance
	`attrs`, per-itemType maxStacks) and tallies per-kind / per-itemType counts. Does NOT apply a
	container entry-capacity policy — the caller does that over the returned `kindCounts`.
	@param items { PlayerDataTypes.InventoryEntry } -- the container's entry array
	@param label string -- the container name for rejection messages ("inventory", "bank")
	@return boolean -- ok
	@return string? -- reason on failure
	@return ShapeCheckResult? -- counts, present only on success
]=]
function InventoryContainerRules.checkEntryShapes(
	items: { PlayerDataTypes.InventoryEntry },
	label: string
): (boolean, string?, ShapeCheckResult?)
	if type(items) ~= "table" then
		return false, `{label}.items must be a table, got {type(items)}`
	end

	local seenUids: { [string]: boolean } = {}
	local kindCounts: { [string]: number } = {}
	local stackCountsByType: { [string]: number } = {}

	for index, entry in items do
		if type(entry) ~= "table" then
			return false, `{label}.items[{index}] must be a table, got {type(entry)}`
		end
		if type(entry.itemType) ~= "string" or not ItemRegistry.isValidItemType(entry.itemType) then
			return false, `{label}.items[{index}] has unregistered itemType "{tostring(entry.itemType)}"`
		end

		local definition = ItemRegistry.get(entry.itemType)
		assert(definition, `itemType "{entry.itemType}" passed isValidItemType but is missing from the registry`)
		kindCounts[definition.kind] = (kindCounts[definition.kind] or 0) + 1

		-- Same-shape narrowing to peek at the field the OTHER union member would carry — the runtime
		-- check below is what decides which member this entry actually is (see InventoryUtils' casts).
		local asStack = entry :: PlayerDataTypes.StackEntry -- same-union-member narrowing, see comment above
		local asUnique = entry :: PlayerDataTypes.UniqueEntry -- same-union-member narrowing, see comment above
		if ItemRegistry.isStackable(entry.itemType) then
			if asUnique.uid ~= nil then
				return false, `{label}.items[{index}] ("{entry.itemType}") is stackable but carries a uid`
			end
			local quantity = asStack.quantity
			if type(quantity) ~= "number" or quantity ~= math.floor(quantity) or quantity < 1 then
				return false, `{label}.items[{index}] ("{entry.itemType}") has an invalid quantity {tostring(quantity)}`
			end
			local stackMax = InventoryContainerRules.stackLimitsOf(definition)
			if quantity > stackMax then
				return false,
					`{label}.items[{index}] ("{entry.itemType}") quantity {quantity} exceeds stackMax {stackMax}`
			end
			stackCountsByType[entry.itemType] = (stackCountsByType[entry.itemType] or 0) + 1
		else
			if asStack.quantity ~= nil then
				return false, `{label}.items[{index}] ("{entry.itemType}") is unique but carries a quantity`
			end
			local uid = asUnique.uid
			if type(uid) ~= "string" or uid == "" then
				return false, `{label}.items[{index}] ("{entry.itemType}") has an invalid uid {tostring(uid)}`
			end
			if seenUids[uid] then
				return false, `duplicate uid "{uid}" in {label}`
			end
			seenUids[uid] = true

			-- Per-instance attrs: same rule on ANY path into the slice (see InventoryUtils.validateAttrs).
			local okAttrs, attrsReason = InventoryUtils.validateAttrs(asUnique.attrs)
			if not okAttrs then
				return false, `{label}.items[{index}] ("{entry.itemType}"): {attrsReason}`
			end
		end
	end

	for itemType, stackCount in stackCountsByType do
		local definition = ItemRegistry.get(itemType)
		assert(definition, `itemType "{itemType}" lost its registration mid-validation`)
		local _, maxStacks = InventoryContainerRules.stackLimitsOf(definition)
		if maxStacks and stackCount > maxStacks then
			return false, `itemType "{itemType}" has {stackCount} stacks, exceeding maxStacks ({maxStacks})`
		end
	end

	return true, nil, { kindCounts = kindCounts, stackCountsByType = stackCountsByType }
end

return InventoryContainerRules
