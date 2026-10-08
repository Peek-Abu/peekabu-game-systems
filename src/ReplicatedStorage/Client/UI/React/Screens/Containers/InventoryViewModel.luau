--!strict
--[=[
	InventoryViewModel: the pure derivation behind the Inventory panel. Turns raw `InventoryEntry`s
	(from the `inventory` atom) into `DisplayItem`s the grid and detail render, and owns the category
	filter, name search, and sort — so `InventoryPanel` stays a dumb renderer with nothing to unit-test.

	Plain functions over plain values (no atoms, no Instances, no React), callable from a spec and from a
	render alike. It reads the shared `ItemRegistry` registry (the item's name/rarity/icon/stats live
	there, not on the entry) and mirrors the service's display rules — the affix name prefix
	(`ItemAffixConstants.displayPrefix`) and the registry-driven stack/unique split (`isStackable`).

	@class InventoryViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local ItemAffixConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemAffixConstants)
local RarityDisplay = require(ReplicatedStorage.Client.UI.React.RarityDisplay)

export type SortMode = "alphabetical" | "rarity" | "stats"

--[=[
	The grid/detail's view over the inventory. `category` is an item KIND (weapon/armour/…) to keep, nil
	for all; `search` is a case-insensitive name substring (nil/"" for all). The tab→kind mapping and the
	filter state itself live in the panel — this is a pure argument.
]=]
export type Filter = {
	category: string?,
	-- Narrows further to ONE equip slot (e.g. only helmets). The authored inventory does this when you
	-- click an armour slot on the paperdoll; nil means "every slot in the category".
	equipSlot: string?,
	search: string?,
	sort: SortMode,
	ascending: boolean,
	-- Which container these entries came from, when more than one is on screen at once. Stamped onto
	-- every item AND folded into its key, because a stackable's key is its itemType — so the same
	-- arrows held in the bag and in the bank produce the SAME key, and a screen showing both would
	-- have two different holdings claiming one identity. nil for a screen with a single container.
	containerId: string?,
}

--[=[
	One rendered item. `key` is the React key — a unique's `uid`, or a stack's `itemType` (one stack per
	stackable itemType). `quantity` is set only for stacks; `uid` only for uniques. `statTotal` is the
	summed base stat bonus (0 for non-gear), the "stats" sort key.
]=]
--[=[
	One stat bonus, resolved for display: the stat's id (so a caller can label it) and its value.
]=]
export type StatBonus = { id: string, value: number }

export type DisplayItem = {
	key: string,
	-- The container this came from, when the screen shows more than one (see Filter.containerId).
	containerId: string?,
	itemType: string,
	uid: string?,
	name: string,
	rarity: string,
	rarityRank: number,
	kind: string,
	icon: string?,
	quantity: number?,
	requiredLevel: number?,
	description: string?,
	statTotal: number,
	-- The stack ceiling, for the card's "AMOUNT: n/max" line. Only stackable kinds carry one.
	stackMax: number?,
	-- Every stat the item grants — its definition's base bonuses WITH its rolled affixes folded in,
	-- alphabetically by id (a stable order; map iteration order is undefined). Feeds the detail card's
	-- stat list. NOT the same as statTotal, which sums them for sorting.
	stats: { StatBonus },
	-- Which slot this item equips into, so the card can compare it against what is already worn there.
	equipSlot: string?,
}

local InventoryViewModel = {}

-- Summed EFFECTIVE stat bonus, for the "stats" sort. Derived from the same list the card shows, so the
-- sort can never disagree with the display (it previously summed base bonuses while the card showed
-- base + affixes).
local function statTotalOf(stats: { StatBonus }): number
	local total = 0
	for _, bonus in stats do
		total += bonus.value
	end
	return total
end

-- Every stat an item grants: its definition's base bonuses with its rolled affixes folded on top, the
-- way the old game's ProcessItemStats folds Boosts into the base Stats. An affix is keyed by affixId and
-- names the stat it feeds, so two affixes on the same stat add up rather than overwrite.
-- Alphabetical by id, matching the authored list's ordering of unconfigured stats.
local function statsOf(definition: PlayerDataTypes.ItemDefinition, affixes: { [string]: number }?): { StatBonus }
	local totals: { [string]: number } = {}
	if definition.kind == "weapon" or definition.kind == "armour" then
		local bonuses: { [string]: number }? = definition.statBonuses
		if bonuses ~= nil then
			for id, value in bonuses do
				totals[id] = (totals[id] or 0) + value
			end
		end
	end
	if affixes ~= nil then
		for affixId, value in affixes do
			local affix = ItemAffixConstants.get(affixId)
			if affix ~= nil then
				totals[affix.stat] = (totals[affix.stat] or 0) + value
			end
		end
	end

	local ordered: { StatBonus } = {}
	for id, value in totals do
		table.insert(ordered, { id = id, value = value })
	end
	table.sort(ordered, function(a: StatBonus, b: StatBonus): boolean
		return a.id < b.id
	end)
	return ordered
end

-- Which slot a definition equips into, if its variant has one.
local function equipSlotOf(definition: PlayerDataTypes.ItemDefinition): string?
	if definition.kind ~= "weapon" and definition.kind ~= "armour" then
		return nil
	end
	return definition.equipSlot
end

-- The stack ceiling of a definition, if the variant has one. Weapons/armour are unique items and carry
-- none, so the narrow is the inverse of statsOf's.
local function stackMaxOf(definition: PlayerDataTypes.ItemDefinition): number?
	if definition.kind == "weapon" or definition.kind == "armour" then
		return nil
	end
	return definition.stackMax
end

-- Required level of a definition, if the variant has one (weapon/armour only), via the same narrow.
local function requiredLevelOf(definition: PlayerDataTypes.ItemDefinition): number?
	if definition.kind ~= "weapon" and definition.kind ~= "armour" then
		return nil
	end
	return definition.requiredLevel
end

--[=[
	Resolves one entry to a DisplayItem via its registered definition, or nil if the itemType has no
	definition (a stale/unknown item renders nothing rather than crashing the grid).
	@param entry PlayerDataTypes.InventoryEntry
	@param containerId string? -- qualifies the key when two containers are co-visible (see Filter)
	@param ordinal number? -- the entry's position in its container, which distinguishes one stack of an
		itemType from another (see the key below). Ignored for uniques, which have a uid of their own.
	@return DisplayItem?
]=]
function InventoryViewModel.toDisplay(
	entry: PlayerDataTypes.InventoryEntry,
	containerId: string?,
	ordinal: number?
): DisplayItem?
	local definition = ItemRegistry.get(entry.itemType)
	if definition == nil then
		return nil
	end

	local uid: string? = nil
	local quantity: number? = nil
	local affixes: { [string]: number }? = nil
	local name = definition.name
	if ItemRegistry.isStackable(entry.itemType) then
		local stack = entry :: PlayerDataTypes.StackEntry -- registry says stackable -> a StackEntry (same
		-- registry-driven discriminator + justified cast the shared InventoryUtils uses)
		quantity = stack.quantity
	else
		local unique = entry :: PlayerDataTypes.UniqueEntry -- registry says not stackable -> a UniqueEntry
		-- (carries a uid + optional affixes). The affix prefixes the name, exactly as
		-- InventoryServiceClient.displayName does (the prefix is never stored on the entry).
		uid = unique.uid
		affixes = unique.affixes
		local prefix = ItemAffixConstants.displayPrefix(unique.affixes)
		if prefix ~= nil then
			name = `{prefix} {name}`
		end
	end

	-- Typed local (not a bare return literal) so `kind`'s literal union widens to the `string` field
	-- by assignability instead of the sealed-literal exactness check.
	local stats = statsOf(definition, affixes)

	-- The key is the item's identity WITHIN its container; the container qualifies it when two are
	-- co-visible. Unqualified for a single-container screen, so the inventory's grid and paperdoll keep
	-- matching the same equipped item by key, which is what makes them one decision.
	--
	-- A stackable needs the ORDINAL on top of its itemType, because a container legitimately holds more
	-- than one stack of the same type once the first fills up (InventoryPlacementUtils opens another; the
	-- `maxStacks` bound is optional). Keyed by itemType alone, those stacks collapsed into a single grid
	-- cell — 25 potions at stackMax 10 rendered as one cell reading "5/10" and the other 20 looked
	-- deleted. Uniques keep their uid, which is already unique, so equipped-vs-grid matching is untouched.
	-- Annotated, not inferred: seeded from `uid` (a `string?`) the local would carry the optional through
	-- to the `key` field, which is a plain `string`.
	local base: string
	if uid ~= nil then
		base = uid
	elseif ordinal ~= nil then
		base = `{entry.itemType}#{ordinal}`
	else
		base = entry.itemType
	end
	local item: DisplayItem = {
		key = if containerId ~= nil then `{containerId}:{base}` else base,
		containerId = containerId,
		itemType = entry.itemType,
		uid = uid,
		name = name,
		rarity = definition.rarity,
		rarityRank = RarityDisplay.rank(definition.rarity),
		kind = definition.kind,
		icon = definition.icon,
		quantity = quantity,
		requiredLevel = requiredLevelOf(definition),
		description = definition.description,
		statTotal = statTotalOf(stats),
		stats = stats,
		equipSlot = equipSlotOf(definition),
		stackMax = stackMaxOf(definition),
	}
	return item
end

--[=[
	One stat row on the detail card: the stat, this item's value, and how it compares with whatever is
	already worn in the same slot. `delta` is nil when there is nothing to compare against.
]=]
export type StatRow = { id: string, value: number, delta: number? }

--[=[
	The detail card's stat rows: this item's stats compared against the item equipped in its slot.

	Includes stats the EQUIPPED item has that this one does not, at value 0 with a negative delta — the
	authored list does the same, so you can see what a swap would cost you, not just what it gains.

	`equippedItem` is the item worn in this item's slot, or nil (nothing worn, or the item does not equip
	at all) — in which case every row's delta is nil and the card shows plain values.
	@param item DisplayItem
	@param equippedItem DisplayItem?
	@return { StatRow }
]=]
function InventoryViewModel.statRows(item: DisplayItem, equippedItem: DisplayItem?): { StatRow }
	local equippedValues: { [string]: number } = {}
	if equippedItem ~= nil and equippedItem.key ~= item.key then
		for _, bonus in equippedItem.stats do
			equippedValues[bonus.id] = bonus.value
		end
	end

	local rows: { StatRow } = {}
	local seen: { [string]: boolean } = {}
	local comparing = equippedItem ~= nil and equippedItem.key ~= item.key

	for _, bonus in item.stats do
		seen[bonus.id] = true
		local row: StatRow = { id = bonus.id, value = bonus.value }
		if comparing then
			row.delta = bonus.value - (equippedValues[bonus.id] or 0)
		end
		table.insert(rows, row)
	end

	-- What the swap would LOSE: stats only the equipped item has.
	for id, equippedValue in equippedValues do
		if not seen[id] then
			table.insert(rows, { id = id, value = 0, delta = -equippedValue })
		end
	end

	table.sort(rows, function(a: StatRow, b: StatRow): boolean
		return a.id < b.id
	end)
	return rows
end

--[=[
	What picking a sort mode does: choosing the ACTIVE mode flips direction, choosing another switches to
	it and keeps the direction.

	Pure and here rather than inside the hook that calls it, so the rule is testable — it is the kind of
	thing that reads as obviously right and is easy to get backwards (flipping on a switch, or resetting
	direction on a flip), and it was written out in two components before the hook existed.
	@param current SortMode -- the active mode
	@param ascending boolean -- the active direction
	@param picked SortMode -- the mode the player just chose
	@return SortMode -- the mode to apply
	@return boolean -- the direction to apply
]=]
function InventoryViewModel.nextSort(current: SortMode, ascending: boolean, picked: SortMode): (SortMode, boolean)
	if picked == current then
		return current, not ascending
	end
	return picked, ascending
end

--[=[
	The equipped view: resolves each occupied equip slot to a DisplayItem, keyed by slot id. Slots with
	nothing in them are simply absent from the result — the paperdoll renders an empty slot for any id it
	does not find, so "unequipped" and "equipped with an item whose definition vanished" both degrade to
	the same harmless empty cell rather than erroring.
	@param equipment PlayerDataTypes.Equipment
	@return { [string]: DisplayItem }
]=]
function InventoryViewModel.equipped(equipment: PlayerDataTypes.Equipment): { [string]: DisplayItem }
	local resolved: { [string]: DisplayItem } = {}
	for slotId, entry in equipment.slots do
		-- Deliberately UNqualified: an equipped item must share its key with the same item in the grid,
		-- which is what lets the panel treat both as one decision.
		local item = InventoryViewModel.toDisplay(entry)
		if item ~= nil then
			resolved[slotId] = item
		end
	end
	return resolved
end

--[=[
	The full grid view: maps entries to DisplayItems, drops unresolved ones, filters by category and
	name search, and sorts. Alphabetical sorts by name; rarity by flavour rank; stats by summed base
	bonus — each with a name tie-break for stable order, and `ascending = false` reversing the primary
	key.
	@param entries { PlayerDataTypes.InventoryEntry }
	@param filter Filter
	@return { DisplayItem }
]=]
function InventoryViewModel.build(entries: { PlayerDataTypes.InventoryEntry }, filter: Filter): { DisplayItem }
	local items: { DisplayItem } = {}
	local query = if filter.search ~= nil then string.lower(filter.search) else ""
	for index, entry in entries do
		-- The ordinal is the entry's index in the SOURCE list, not in the filtered output, so a key stays
		-- put as the player types in the search box or flips the sort.
		local item = InventoryViewModel.toDisplay(entry, filter.containerId, index)
		if item == nil then
			continue
		end
		if filter.category ~= nil and item.kind ~= filter.category then
			continue
		end
		if filter.equipSlot ~= nil and item.equipSlot ~= filter.equipSlot then
			continue
		end
		if query ~= "" and string.find(string.lower(item.name), query, 1, true) == nil then
			continue
		end
		table.insert(items, item)
	end

	table.sort(items, function(a: DisplayItem, b: DisplayItem): boolean
		local nameA, nameB = string.lower(a.name), string.lower(b.name)
		if filter.sort == "alphabetical" then
			-- Name IS the primary key here.
			if nameA ~= nameB then
				return if filter.ascending then nameA < nameB else nameA > nameB
			end
			return false
		end
		-- rarity / stats: a numeric primary key, then name (always ascending) as the tie-break.
		local primaryA = if filter.sort == "rarity" then a.rarityRank else a.statTotal
		local primaryB = if filter.sort == "rarity" then b.rarityRank else b.statTotal
		if primaryA ~= primaryB then
			return if filter.ascending then primaryA < primaryB else primaryA > primaryB
		end
		return nameA < nameB
	end)

	return items
end

return InventoryViewModel
