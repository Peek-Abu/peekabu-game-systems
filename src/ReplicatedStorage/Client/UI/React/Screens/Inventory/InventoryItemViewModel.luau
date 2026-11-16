--!strict
--[=[
	InventoryItemViewModel: an employee page's item cards and the selected item's detail panel, worked out from the
	catalogue (CosmeticRegistry), the player's loadout and what they own. Split out of InventoryViewModel, which
	re-exports all of it (callers keep using InventoryViewModel).

	- `items`: an employee's skins, emotes, idles or vacuum skins as grid cards (the free one first, then by rarity).
	- `band` / `action`: where a locked item comes from (the card's footer) and the detail panel's main button.
	- `detail`: the right-hand panel for the selected item (flags, lore, Styles row, Comes with, wheel, button).

	@class InventoryItemViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetic = ReplicatedStorage.Shared.Features.Cosmetic
local CosmeticRegistry = require(Cosmetic.Data.CosmeticRegistry)
local CosmeticBundleRegistry = require(Cosmetic.Data.CosmeticBundleRegistry)
local CosmeticRules = require(Cosmetic.Rules.CosmeticRules)
local CosmeticTypes = require(Cosmetic.Data.CosmeticTypes)
local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local EmoteRules = require(ReplicatedStorage.Shared.Features.Emote.Rules.EmoteRules)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local ToonSourceBand = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSourceBand)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)

type Item = CosmeticTypes.Item
type Loadout = CosmeticTypes.Loadout
type Owns = (id: string) -> boolean

export type Band = { kind: ToonSourceBand.Kind, text: string }
-- `kind`: what pressing it does: wear the item, open its Shop page, or nothing (it says where to get the item).
-- `price`: shown on a Shop button.
export type Action = {
	text: string,
	enabled: boolean,
	variant: ToonStyleViewModel.Variant,
	kind: "wear" | "shop" | "none",
	price: { currency: "gleam" | "credits", amount: string }?,
}
export type Bundled = { id: string, name: string, kind: CosmeticTypes.Kind, employee: string? }
export type ItemCard = {
	id: string,
	name: string,
	rarity: CosmeticTypes.Rarity,
	owned: boolean,
	worn: boolean,
	-- Locked art is darkened.
	dim: boolean,
	new: boolean,
	band: Band?,
	-- A vacuum skin (its card shows the vacuum alone; the hero shows you wearing it, from behind).
	vacuum: boolean,
}

-- One colour style's chip: a short name and its colours (the fur, then the outfit).
export type StyleChip = { name: string, swatch: { Color3 } }

export type Detail = {
	id: string,
	name: string,
	rarity: CosmeticTypes.Rarity,
	rarityText: string,
	new: boolean,
	-- "Pippa skin", "Idle for everyone".
	line: string,
	lore: string,
	-- The lore is the employee speaking (the item's choice): drawn with a quote mark and signed; otherwise a book.
	quote: boolean,
	-- The colour styles: a chip each (its name and colours) only for a skin with real styles (no row otherwise).
	-- Chips preview the style on the hero (never equip: Wear does). `selected` is the style shown: the previewed one,
	-- else the worn one, else 1.
	styles: { visible: boolean, count: number, enabled: boolean, selected: number, chips: { StyleChip } },
	-- The other items of the bundle it is in ("In a bundle with"); empty when it is in none.
	comesWith: { Bundled },
	action: Action,
	-- Emotes: the employee's 4 wheel slots, the free slot "Add to wheel" uses (nil = none free), and whether its clip
	-- is still to come (it can be put on the wheel but does not play yet).
	wheel: { WheelSlot }?,
	wheelSlot: number?,
	comingSoon: boolean,
}

-- One emote-wheel slot on the detail panel: what is in it (`mine` = the item shown).
export type WheelSlot = { slot: number, id: string?, name: string, empty: boolean, mine: boolean }

-- The kinds a page lists.
export type ListKind = "skin" | "emote" | "idle" | "vacuum"

local RARITY_RANK: { [CosmeticTypes.Rarity]: number } = {
	default = 0,
	uncommon = 1,
	rare = 2,
	epic = 3,
	legendary = 4,
	odd = 5,
}

local InventoryItemViewModel = {}

-- The footer band: nil for an owned item, "Wearing" on the worn one, else where it comes from.
function InventoryItemViewModel.band(item: Item, owned: boolean, worn: boolean): Band?
	if worn then
		return { kind = "wearing", text = "Wearing" }
	end
	if owned then
		return nil
	end
	local source = item.source
	if source == "credits" or source == "gleam" then
		return { kind = source, text = if item.price ~= nil then ToonStyleViewModel.grouped(item.price) else "Shop" }
	elseif source == "gloomLocker" then
		return { kind = "locker", text = "Gloom Locker" }
	elseif source == "gleamLocker" then
		return { kind = "locker", text = "Gleam Locker" }
	elseif source == "goal" then
		return { kind = "goal", text = "Goal" }
	elseif source == "event" or source == "gift" then
		return { kind = "missed", text = "Missed it" }
	elseif source == "later" then
		return { kind = "later", text = "Coming later" }
	end
	-- A free item is always owned; kept for completeness.
	return nil
end

-- The detail panel's main button. Only Wear does anything; the rest say where to get the item.
function InventoryItemViewModel.action(item: Item, owned: boolean, worn: boolean): Action
	if worn then
		return { text = "Wearing", enabled = false, variant = "secondary", kind = "none" }
	end
	if owned then
		return { text = "Wear", enabled = true, variant = "primary", kind = "wear" }
	end
	local source = item.source
	if (source == "credits" or source == "gleam") and item.price ~= nil then
		return {
			text = "See in Shop",
			enabled = true,
			variant = "gleam",
			kind = "shop",
			price = { currency = source, amount = ToonStyleViewModel.grouped(item.price) },
		}
	elseif source == "gloomLocker" then
		return { text = "Gloom Locker", enabled = false, variant = "night", kind = "none" }
	elseif source == "gleamLocker" then
		return { text = "Gleam Locker", enabled = false, variant = "gleam", kind = "none" }
	elseif source == "goal" then
		return { text = "Earn it playing", enabled = false, variant = "primary", kind = "none" }
	elseif source == "event" or source == "gift" then
		return { text = "Missed it", enabled = false, variant = "secondary", kind = "none" }
	end
	return { text = "Coming later", enabled = false, variant = "lilac", kind = "none" }
end

-- The wheel slot `id` sits in on `employee`'s emote wheel (nil = not on it).
local function slotOf(id: string, employee: string, loadout: Loadout, owns: Owns): number?
	local wheel = CosmeticRules.lookFor(loadout, employee, owns).wheel
	for slot, other in wheel do
		if other == id then
			return slot
		end
	end
	return nil
end

local function wornId(kind: ListKind, employee: string, loadout: Loadout, owns: Owns): string
	if kind == "emote" then
		-- Emotes are "worn" by slot (several at once): see `items`.
		return ""
	elseif kind == "vacuum" then
		return CosmeticRules.vacuumFor(loadout, owns)
	end
	local look = CosmeticRules.lookFor(loadout, employee, owns)
	return if kind == "skin" then look.skin else look.idle
end

local function isNew(item: Item, owned: boolean, loadout: Loadout): boolean
	return owned and item.source ~= "default" and loadout.seen[item.id] ~= true
end

-- The name of the first skin an idle fits ("Bubble Buddy"), for "Bubble Buddy only"; nil when it fits every skin.
local function fitsName(item: Item): string?
	local fits = item.fits
	local skin = if fits ~= nil and fits[1] ~= nil then CosmeticRegistry.get(fits[1]) else nil
	return if skin ~= nil then skin.name else nil
end

-- Whether `item` is an idle that does not fit the skin `employee` wears (it is locked for that skin).
local function idleLocked(item: Item, employee: string, loadout: Loadout, owns: Owns): boolean
	return item.kind == "idle"
		and not CosmeticRules.idleFits(item.id, CosmeticRules.lookFor(loadout, employee, owns).skin)
end

-- The employee's skins or idles (idles include the shared ones), the free one first, then by rarity.
function InventoryItemViewModel.items(kind: ListKind, employee: string, loadout: Loadout, owns: Owns): { ItemCard }
	local worn = wornId(kind, employee, loadout, owns)
	local list = table.clone(CosmeticRegistry.ofKind(kind, employee))
	table.sort(list, function(a: Item, b: Item): boolean
		local fa = a.source == "default" and (a.employee == employee or a.employee == nil)
		local fb = b.source == "default" and (b.employee == employee or b.employee == nil)
		if fa ~= fb then
			return fa
		end
		if RARITY_RANK[a.rarity] ~= RARITY_RANK[b.rarity] then
			return RARITY_RANK[a.rarity] < RARITY_RANK[b.rarity]
		end
		return a.id < b.id
	end)
	local cards: { ItemCard } = {}
	for _, item in list do
		local owned = owns(item.id)
		local slot = if kind == "emote" then slotOf(item.id, employee, loadout, owns) else nil
		local isWorn = item.id == worn or slot ~= nil
		local onSlot: Band? = if slot ~= nil then { kind = "wearing", text = `Slot {slot}` } else nil
		-- An owned idle that does not fit the worn skin: locked, and the band names the skin it needs.
		local locked = owned and idleLocked(item, employee, loadout, owns)
		local needs = if locked then fitsName(item) else nil
		local lockedBand: Band? = if needs ~= nil then { kind = "later", text = `{needs} only` } else nil
		local band = onSlot or lockedBand or InventoryItemViewModel.band(item, owned, isWorn)
		table.insert(cards, {
			id = item.id,
			name = item.name,
			rarity = item.rarity,
			owned = owned,
			worn = isWorn,
			dim = not owned or locked,
			new = isNew(item, owned, loadout),
			band = band,
			vacuum = item.kind == "vacuum",
		})
	end
	return cards
end

--[=[
	The detail panel for `item`. `style` is the colour style previewed on a chip (nil = the worn style, else 1): each
	style acts like its own skin, so a worn skin previewed in another style offers Wear for it (chips never equip).
]=]
function InventoryItemViewModel.detail(item: Item, loadout: Loadout, owns: Owns, page: string?, style: number?): Detail
	local owned = owns(item.id)
	local employee = item.employee
	local worn = false
	if employee ~= nil and (item.kind == "skin" or item.kind == "idle") then
		worn = wornId(item.kind, employee, loadout, owns) == item.id
	elseif item.kind == "vacuum" then
		worn = CosmeticRules.vacuumFor(loadout, owns) == item.id
	end
	-- The other items of the first bundle it is in (CosmeticBundleRegistry); the item itself is never one.
	local comesWith: { Bundled } = {}
	local bundle = CosmeticBundleRegistry.containing(item.id)[1]
	if bundle ~= nil then
		for _, id in bundle.items do
			local other = if id ~= item.id then CosmeticRegistry.get(id) else nil
			if other ~= nil then
				table.insert(
					comesWith,
					{ id = other.id, name = other.name, kind = other.kind, employee = other.employee }
				)
			end
		end
	end
	local kindWord = if item.kind == "idle"
		then "idle"
		elseif item.kind == "emote" then "emote"
		elseif item.kind == "vacuum" then "vacuum"
		else "skin"
	local chips: { StyleChip } = {}
	if item.kind == "skin" then
		for _, styleDef in EmployeeSkinRules.stylesFor(employee, CosmeticRegistry.keyOf(item.id)) do
			table.insert(chips, { name = styleDef.name, swatch = styleDef.swatch })
		end
	end
	local wornStyle = 1
	if worn and employee ~= nil and #chips > 0 then
		local look = CosmeticRules.lookFor(loadout, employee, owns).style
		wornStyle = if chips[look] ~= nil then look else 1
	end
	local selectedStyle = if style ~= nil and chips[style] ~= nil then style else wornStyle
	local action = InventoryItemViewModel.action(item, owned, worn and selectedStyle == wornStyle)
	local needs = if owned
			and employee ~= nil
			and idleLocked(item, employee, loadout, owns)
		then fitsName(item)
		else nil
	if needs ~= nil then
		action = { text = `Wear {needs} first`, enabled = false, variant = "secondary", kind = "none" }
	end
	local wheel: { WheelSlot }? = nil
	local wheelSlot: number? = nil
	local comingSoon = false
	local wheelOf = item.employee or page
	if item.kind == "emote" and wheelOf ~= nil then
		local slots: { WheelSlot } = {}
		local mine: number? = nil
		for slot, id in CosmeticRules.lookFor(loadout, wheelOf, owns).wheel do
			local other = if id ~= "" then CosmeticRegistry.get(id) else nil
			if id == item.id then
				mine = mine or slot
			end
			if other == nil and wheelSlot == nil then
				wheelSlot = slot
			end
			table.insert(slots, {
				slot = slot,
				id = if other ~= nil then other.id else nil,
				name = if other ~= nil then other.name else "Empty",
				empty = other == nil,
				mine = id == item.id,
			})
		end
		wheel = slots
		comingSoon = AnimationRegistry.get(EmoteRules.clipKey(item.id)) == nil
		if mine ~= nil then
			wheelSlot = nil
			action = { text = `On slot {mine}`, enabled = false, variant = "secondary", kind = "none" }
		elseif owned and wheelSlot ~= nil then
			action = { text = "Add to wheel", enabled = true, variant = "primary", kind = "wear" }
		elseif owned then
			action = { text = "Pick a slot below", enabled = false, variant = "secondary", kind = "none" }
		end
		if not owned then
			wheelSlot = nil
		end
	end
	return {
		id = item.id,
		name = item.name,
		rarity = item.rarity,
		rarityText = if item.rarity == "default" then "CLASSIC" else string.upper(item.rarity),
		new = isNew(item, owned, loadout),
		line = if employee ~= nil
			then `{employee} {kindWord}`
			elseif item.kind == "vacuum" then "Vacuum for every employee"
			else `{kindWord} for everyone`,
		lore = item.lore,
		quote = item.quote == true,
		styles = {
			visible = #chips > 0,
			count = #chips,
			enabled = owned and #chips > 0,
			selected = selectedStyle,
			chips = chips,
		},
		comesWith = comesWith,
		action = action,
		wheel = wheel,
		wheelSlot = wheelSlot,
		comingSoon = comingSoon,
	}
end

return InventoryItemViewModel
