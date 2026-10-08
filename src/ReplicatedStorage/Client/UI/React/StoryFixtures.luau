--!strict
--[=[
	StoryFixtures: the sample data the UI Labs stories render, so a story stays about LAYOUT rather than
	about assembling test items inline five times over.

	Two kinds of fixture, because the components take two kinds of input:

	- `displayItems` / `rarityLadder` build `DisplayItem`s DIRECTLY. The presentational pieces (Slot,
	  ItemGrid, ItemDetail) take those, so a story can show a rarity that no registered item happens to
	  have — including the empty slot, which is otherwise only reachable once equipment slots exist.
	- `seedInventory` writes REAL entries into the `inventory` atom, for the panel, which reads the atom
	  rather than taking props. That deliberately runs the real `ItemContentRegistry` → `ItemRegistry` →
	  `InventoryViewModel` path, so a story catches a break in it.

	Ships in the place (everything under `src/ReplicatedStorage` does), but nothing at runtime requires
	it — only `*.story` modules do, and only the UI Labs plugin loads those.

	@class StoryFixtures
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemShared = ReplicatedStorage.Shared.Features.Item
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local ItemContentRegistry = require(ItemShared.Data.ItemContentRegistry)
local ItemConstants = require(ItemShared.Data.ItemConstants)
local ItemRegistry = require(ItemShared.Data.ItemRegistry)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)
local InventoryUtils = require(ReplicatedStorage.Shared.Features.Inventory.Utils.InventoryUtils)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local RarityDisplay = require(ReplicatedStorage.Client.UI.React.RarityDisplay)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Containers.InventoryViewModel)

local StoryFixtures = {}

-- Starting balances for the bank story, chosen so the readouts show thousands separators and the two
-- sides are visibly different numbers.
local PURSE_COINS = 2_000
local BANK_COINS = 12_500
-- Annotated: `Currency` is keyed by the CurrencyType union, and an inferred "jaku" widens to `string`,
-- which the indexer then rejects.
local COIN: CurrencyConstants.CurrencyType = "jaku"

--[=[
	A one-currency balance, built through the indexer rather than as a literal (a sealed literal is not
	exactly-assignable to an indexed table type).
	@param amount number
	@return PlayerDataTypes.Currency
]=]
local function balance(amount: number): PlayerDataTypes.Currency
	local currency: PlayerDataTypes.Currency = {}
	currency[COIN] = amount
	return currency
end

-- Fixture names, one per rarity rung, so a ladder reads as six distinct items rather than six clones.
local NAMES: { [string]: string } = {
	common = "Rusted Saw Blade",
	uncommon = "Hunter's Hatchet",
	rare = "Tidecaller Spear",
	epic = "Duskwoven Mantle",
	legendary = "Phoenix Blade",
	cursed = "Gravebound Sickle",
}

--[=[
	The registered rarities in RANK order (the shared list is sorted alphabetically on purpose and
	explicitly does not rank).
	@return { string }
]=]
function StoryFixtures.rarities(): { string }
	local ordered = table.clone(ItemConstants.RARITIES)
	table.sort(ordered, function(a: string, b: string): boolean
		return RarityDisplay.rank(a) < RarityDisplay.rank(b)
	end)
	return ordered
end

--[=[
	One `DisplayItem` at the given rarity. `index` only varies the key, so a list of these reconciles.
	@param rarity string
	@param index number
	@return InventoryViewModel.DisplayItem
]=]
function StoryFixtures.displayItem(rarity: string, index: number): InventoryViewModel.DisplayItem
	local item: InventoryViewModel.DisplayItem = {
		key = `fixture-{rarity}-{index}`,
		itemType = `fixture-{rarity}`,
		name = NAMES[rarity] or "Unnamed Fixture",
		rarity = rarity,
		rarityRank = RarityDisplay.rank(rarity),
		kind = "weapon",
		requiredLevel = 5 * RarityDisplay.rank(rarity),
		description = "A fixture item, standing in for the real thing while the layout is dialled in.",
		statTotal = 7 * RarityDisplay.rank(rarity),
		-- No stackMax: fixtures stand in for gear, whose primary line stays reserved until damage exists.
		-- Two bonuses so the card's secondary-stat grid has more than one row to lay out.
		stats = {
			{ id = "strength", value = 5 * RarityDisplay.rank(rarity) },
			{ id = "rotEndurance", value = 2 * RarityDisplay.rank(rarity) },
		},
	}
	return item
end

--[=[
	One item per rarity, lowest rung first — the ladder for eyeballing the slot border tints side by side.
	@return { InventoryViewModel.DisplayItem }
]=]
function StoryFixtures.rarityLadder(): { InventoryViewModel.DisplayItem }
	local items: { InventoryViewModel.DisplayItem } = {}
	for index, rarity in StoryFixtures.rarities() do
		table.insert(items, StoryFixtures.displayItem(rarity, index))
	end
	return items
end

--[=[
	A weaker stand-in for "what you already have equipped", so the detail card's comparison shows all three
	cases at once: a stat that gains, a stat that loses, and a stat only the EQUIPPED item has (which the
	card must still list, at zero, so the cost of a swap is visible).
	@return InventoryViewModel.DisplayItem
]=]
function StoryFixtures.comparisonItem(): InventoryViewModel.DisplayItem
	local item = StoryFixtures.displayItem("rare", 99)
	item.key = "fixture-equipped"
	item.name = "Worn Blade"
	item.stats = {
		{ id = "strength", value = 4 }, -- lower than the shown item: a gain
		{ id = "stamina", value = 6 }, -- absent from the shown item: a loss, listed at zero
	}
	return item
end

--[=[
	`count` items cycling through the rarity ladder, for filling a grid.
	@param count number
	@return { InventoryViewModel.DisplayItem }
]=]
function StoryFixtures.displayItems(count: number): { InventoryViewModel.DisplayItem }
	local rarities = StoryFixtures.rarities()
	local items: { InventoryViewModel.DisplayItem } = {}
	for index = 1, count do
		table.insert(items, StoryFixtures.displayItem(rarities[(index - 1) % #rarities + 1], index))
	end
	return items
end

--[=[
	Writes `count` REAL registered items into the `inventory` atom, for the panel (which reads the atom,
	not props). Registers the game's items first — `ItemContentRegistry.init` guards its own re-entry, so calling
	it from every story render is safe.
	@param count number -- how many entries to seed; cycles the registered item types
]=]
function StoryFixtures.seedInventory(count: number)
	ItemContentRegistry.init()

	local itemTypes = ItemRegistry.getValidItemTypes()
	table.sort(itemTypes) -- registry order is a hash walk; sort so a story renders the same list twice

	local entries: { PlayerDataTypes.InventoryEntry } = {}
	for index = 1, count do
		local itemType = itemTypes[(index - 1) % #itemTypes + 1]
		if ItemRegistry.isStackable(itemType) then
			local stack: PlayerDataTypes.StackEntry = { itemType = itemType, quantity = index }
			table.insert(entries, stack)
		else
			local unique: PlayerDataTypes.UniqueEntry = { itemType = itemType, uid = `fixture-uid-{index}` }
			table.insert(entries, unique)
		end
	end

	StateSyncClientStore.inventory({ items = entries })
end

--[=[
	Equips real items into a couple of slots, so the paperdoll story shows both filled and EMPTY cells —
	the empty ones being the whole reason the paperdoll is worth previewing.
]=]
function StoryFixtures.seedEquipment()
	ItemContentRegistry.init()

	local slots: { [string]: PlayerDataTypes.UniqueEntry } = {}
	for _, itemType in ItemRegistry.getValidItemTypes() do
		local kind = ItemRegistry.kindOf(itemType)
		if kind == "weapon" and slots.weapon == nil then
			slots.weapon = { itemType = itemType, uid = "fixture-equipped-weapon" }
		elseif kind == "armour" and slots.helmet == nil then
			slots.helmet = { itemType = itemType, uid = "fixture-equipped-helmet" }
		end
	end

	StateSyncClientStore.equipment({ slots = slots })
end

--[=[
	Equip/unequip actions that write the seeded ATOMS directly, for `InventoryPanel` in UI Labs.

	The panel takes these as a prop precisely so a story can stand in for the server: the real actions go
	through ByteNet, which has nothing to talk to in edit mode. This mirrors the server's swap — equipping
	takes the item out of the inventory and returns whatever it displaced — so dragging an item onto a full
	slot previews the same way it will behave in game. It is a PREVIEW, not a model of the rules: none of
	the server's refusals (level requirement, kind caps, slot validation) are reproduced here, because a
	story is for looking at the screen, not for trusting it.
	@return { equip: (string) -> (), unequip: (string) -> () }
]=]
function StoryFixtures.localEquipment(): { equip: (string) -> (), unequip: (string) -> () }
	local function equip(uid: string)
		local inventory = StateSyncClientStore.inventory()
		local index, entry = InventoryUtils.findByUid(inventory, uid)
		if index == nil or entry == nil then
			return
		end
		-- Only gear carries an `equipSlot`, so the definition union is narrowed by `kind` first — as its own
		-- check, since folding the nil test into the same condition stops the narrowing from applying.
		local definition = ItemRegistry.get(entry.itemType)
		if definition == nil then
			return
		end
		if definition.kind ~= "weapon" and definition.kind ~= "armour" then
			return
		end
		local slotId = definition.equipSlot

		local items = table.clone(inventory.items)
		table.remove(items, index)
		local slots = table.clone(StateSyncClientStore.equipment().slots)
		local displaced = slots[slotId]
		if displaced ~= nil then
			table.insert(items, displaced) -- the swap: what was worn goes back to the grid
		end
		slots[slotId] = entry

		StateSyncClientStore.inventory({ items = items })
		StateSyncClientStore.equipment({ slots = slots })
	end

	local function unequip(slotId: string)
		local slots = table.clone(StateSyncClientStore.equipment().slots)
		local worn = slots[slotId]
		if worn == nil then
			return
		end
		slots[slotId] = nil

		local items = table.clone(StateSyncClientStore.inventory().items)
		table.insert(items, worn)

		StateSyncClientStore.inventory({ items = items })
		StateSyncClientStore.equipment({ slots = slots })
	end

	return { equip = equip, unequip = unequip }
end

--[=[
	Writes `count` REAL registered items into the `bank` atom, offset from `seedInventory`'s slice of the
	registry so the two sides of the bank story do not show the same list twice.
	@param count number
]=]
function StoryFixtures.seedBank(count: number)
	ItemContentRegistry.init()

	local itemTypes = ItemRegistry.getValidItemTypes()
	table.sort(itemTypes) -- registry order is a hash walk; sort so a story renders the same list twice

	local entries: { PlayerDataTypes.InventoryEntry } = {}
	for index = 1, count do
		-- Walk the registry BACKWARDS, so the bank leads with the item types the bag ends on.
		local itemType = itemTypes[#itemTypes - ((index - 1) % #itemTypes)]
		-- Typed locals rather than casts, matching seedInventory: the annotation IS the assertion.
		if ItemRegistry.isStackable(itemType) then
			local stack: PlayerDataTypes.StackEntry = { itemType = itemType, quantity = index }
			table.insert(entries, stack)
		else
			local unique: PlayerDataTypes.UniqueEntry = { itemType = itemType, uid = `fixture-bank-uid-{index}` }
			table.insert(entries, unique)
		end
	end

	local vault: PlayerDataTypes.Bank = { items = entries, currency = balance(BANK_COINS) }
	StateSyncClientStore.bank(vault)
	StateSyncClientStore.currency(balance(PURSE_COINS))
end

--[=[
	Transfer actions that move entries between the seeded `inventory` and `bank` atoms, for `BankPanel`
	in UI Labs.

	Stands in for the server, which the real actions reach through ByteNet — nothing to talk to in edit
	mode. Whole-holding, matching the server: a stackable moves every entry of its itemType at once.

	A PREVIEW, not a model of the rules: neither container's capacity is checked here, so the one case
	only the server can decide — a full bank, or a withdrawal that would breach the bag's per-kind cap —
	is exactly what this cannot show.
	@return { the six transfer verbs, over the seeded atoms }
]=]
function StoryFixtures.localBank(): {
	depositUnique: (string) -> (),
	withdrawUnique: (string) -> (),
	depositStack: (string) -> (),
	withdrawStack: (string) -> (),
	depositCurrency: (CurrencyConstants.CurrencyType, number) -> (),
	withdrawCurrency: (CurrencyConstants.CurrencyType, number) -> (),
}
	-- One mover for all four verbs: they differ only in direction and in how the entry is matched.
	local function move(fromBank: boolean, matches: (PlayerDataTypes.InventoryEntry) -> boolean)
		local bag = table.clone(StateSyncClientStore.inventory().items)
		local vault = StateSyncClientStore.bank()
		local banked = table.clone(vault.items)
		local source = if fromBank then banked else bag
		local destination = if fromBank then bag else banked

		local moved = false
		for index = #source, 1, -1 do
			if matches(source[index]) then
				table.insert(destination, table.remove(source, index))
				moved = true
			end
		end
		if not moved then
			return
		end
		StateSyncClientStore.inventory({ items = bag })
		StateSyncClientStore.bank({ items = banked, currency = vault.currency })
	end

	local function byUid(uid: string)
		return function(entry: PlayerDataTypes.InventoryEntry): boolean
			local unique = entry :: PlayerDataTypes.UniqueEntry -- a uid match only ever hits a unique entry
			return unique.uid == uid
		end
	end
	local function byType(itemType: string)
		return function(entry: PlayerDataTypes.InventoryEntry): boolean
			return entry.itemType == itemType
		end
	end

	-- Currency is the one thing here carrying an amount (items move as whole holdings), so it is the one
	-- mover that has to clamp: the real server refuses an over-draw, and a preview that silently allowed
	-- a negative balance would be showing something that cannot happen.
	local function moveCoins(fromBank: boolean, amount: number)
		local vault = StateSyncClientStore.bank()
		local purse: PlayerDataTypes.Currency = StateSyncClientStore.currency() or {}
		local banked = vault.currency[COIN] or 0
		local held = purse[COIN] or 0
		local moved = math.min(amount, if fromBank then banked else held)
		if moved <= 0 then
			return
		end
		local delta = if fromBank then moved else -moved
		local updated: PlayerDataTypes.Bank = { items = vault.items, currency = balance(banked - delta) }
		StateSyncClientStore.currency(balance(held + delta))
		StateSyncClientStore.bank(updated)
	end

	return {
		depositCurrency = function(_currencyType: CurrencyConstants.CurrencyType, amount: number)
			moveCoins(false, amount)
		end,
		withdrawCurrency = function(_currencyType: CurrencyConstants.CurrencyType, amount: number)
			moveCoins(true, amount)
		end,
		depositUnique = function(uid: string)
			move(false, byUid(uid))
		end,
		withdrawUnique = function(uid: string)
			move(true, byUid(uid))
		end,
		depositStack = function(itemType: string)
			move(false, byType(itemType))
		end,
		withdrawStack = function(itemType: string)
			move(true, byType(itemType))
		end,
	}
end

return StoryFixtures
