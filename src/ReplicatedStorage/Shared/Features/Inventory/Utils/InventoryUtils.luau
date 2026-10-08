--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryUtils = {}

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)

--[=[
	Pure query surface over the `{ items: { InventoryEntry } }` wrapper (StackEntry | UniqueEntry —
	see PlayerDataTypes). No mutation here: adding/removing entries (uid minting, all-or-nothing
	batches, the size/kind-cap validator) is InventoryServiceServer's job.

	`InventoryEntry` carries no shared literal tag field to discriminate on (unlike `ItemDefinition`'s
	`kind`), so a StackEntry and a UniqueEntry cannot be told apart from the entry alone. Instead every
	function below asks the registry — `ItemRegistry.isStackable(entry.itemType)` — which is the
	single source of truth for "is this itemType's entries a StackEntry or a UniqueEntry". Each `::`
	cast in this module immediately follows that check and narrows only the branch it guards.
]=]

--[=[
	Total quantity of `itemType` held in `inventory`: every matching StackEntry's `quantity` summed
	(a stackable itemType may legitimately be split across more than one stack), or the number of
	matching UniqueEntry instances (a unique itemType has no quantity field — each instance is a
	physical "1").
	@param inventory PlayerDataTypes.Inventory
	@param itemType string
	@return number
]=]
function InventoryUtils.countOf(inventory: PlayerDataTypes.Inventory, itemType: string): number
	local total = 0
	for _, entry in inventory.items do
		if entry.itemType ~= itemType then
			continue
		end
		if ItemRegistry.isStackable(entry.itemType) then
			-- Registry says stackable: this entry was stored as a StackEntry.
			local stack = entry :: PlayerDataTypes.StackEntry
			total += stack.quantity
		else
			total += 1
		end
	end
	return total
end

--[=[
	Finds a UniqueEntry by its `uid`. Only unique entries carry a uid, so this never matches a
	StackEntry.
	@param inventory PlayerDataTypes.Inventory
	@param uid string
	@return number? -- the entry's index into `inventory.items`, or nil if not found
	@return PlayerDataTypes.UniqueEntry? -- the matching entry, or nil if not found
]=]
function InventoryUtils.findByUid(
	inventory: PlayerDataTypes.Inventory,
	uid: string
): (number?, PlayerDataTypes.UniqueEntry?)
	for index, entry in inventory.items do
		if ItemRegistry.isStackable(entry.itemType) then
			continue
		end
		-- Registry says not stackable: this entry was stored as a UniqueEntry.
		local unique = entry :: PlayerDataTypes.UniqueEntry
		if unique.uid == uid then
			return index, unique
		end
	end
	return nil, nil
end

--[=[
	All entries whose itemType's registered definition has the given `kind` (via
	`ItemRegistry.kindOf`). The UI-tab helper: e.g. "weapon" -> every weapon entry, stacks and
	uniques alike. An itemType with no registered definition matches no kind.
	@param inventory PlayerDataTypes.Inventory
	@param kind string
	@return { PlayerDataTypes.InventoryEntry }
]=]
function InventoryUtils.entriesOfKind(
	inventory: PlayerDataTypes.Inventory,
	kind: string
): { PlayerDataTypes.InventoryEntry }
	local out: { PlayerDataTypes.InventoryEntry } = {}
	for _, entry in inventory.items do
		if ItemRegistry.kindOf(entry.itemType) == kind then
			table.insert(out, entry)
		end
	end
	return out
end

--[=[
	Number of ENTRIES (not summed quantity) of a given kind — the KIND_CAPS meter. Two separate
	stacks of the same stackable itemType count as 2 here, even though `countOf` would sum their
	quantities into one number: a kind cap limits how many inventory slots a kind occupies, not how
	many items are held.
	@param inventory PlayerDataTypes.Inventory
	@param kind string
	@return number
]=]
function InventoryUtils.countEntriesOfKind(inventory: PlayerDataTypes.Inventory, kind: string): number
	return #InventoryUtils.entriesOfKind(inventory, kind)
end

--[=[
	True iff `inventory` holds at least `quantity` (default 1) of `itemType`. Built directly on
	`countOf`, so the same "stacks summed / instances counted" semantics apply uniformly: for a
	stackable itemType this checks the total held quantity; for a unique itemType this checks the
	number of distinct instances.
	@param inventory PlayerDataTypes.Inventory
	@param itemType string
	@param quantity number? -- defaults to 1
	@return boolean
]=]
function InventoryUtils.hasItem(inventory: PlayerDataTypes.Inventory, itemType: string, quantity: number?): boolean
	local required = quantity or 1
	return InventoryUtils.countOf(inventory, itemType) >= required
end

--[=[
	Validates a per-instance modifier map that rides on a UniqueEntry (`affixes` or `statRolls`): every
	VALUE must be a finite number. Keys are DELIBERATELY tolerated — an affixId retired from the pool,
	or a stat id removed from the registry, is config-drift, not corruption, and rejecting it would make
	every item carrying it un-saveable (Path of Exile's disable-don't-delete). It also never range-checks
	a value: a "legacy" value outside a since-retuned range is legitimate persisted data, not corruption.
	A nil map is valid (the field is simply absent). See the affix-rolling design spec, Decision 8.
	@param map { [string]: number }? -- an entry's affixes or statRolls
	@return boolean -- ok
	@return string? -- reason on failure
]=]
function InventoryUtils.validateModifierMap(map: { [string]: number }?): (boolean, string?)
	if map == nil then
		return true
	end
	if type(map) ~= "table" then
		return false, `modifier map must be a table, got {type(map)}`
	end
	for key, value in map do
		-- Keys must be non-empty STRINGS. Unknown string ids are tolerated (retired affix / stat — see
		-- above), but a non-string key is malformed/corrupt data: it would later crash the client's
		-- ItemAffixConstants.displayPrefix, which table.sorts the collected keys (mixed types throw). Same
		-- "non-empty string" shape rule validateInventory already enforces on a UniqueEntry's uid.
		if type(key) ~= "string" or key == "" then
			return false, `modifier map has a non-string key {tostring(key)}`
		end
		-- Reject non-numbers and the non-finite doubles (NaN fails `value == value`; ±inf compare direct).
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return false, `modifier "{tostring(key)}" has a non-finite value {tostring(value)}`
		end
	end
	return true
end

return InventoryUtils
