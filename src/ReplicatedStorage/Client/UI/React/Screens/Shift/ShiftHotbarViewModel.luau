--!strict
--[=[
	ShiftHotbarViewModel: what the paper hotbar (ShiftHotbar) shows, from the local player's public entry
	(docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md §4): the vacuum in slot 1 with its
	canister, the four item slots with each item's name and tag, which slot is chosen, and whether a big hands item locks
	them. Pure (specced).

	@class ShiftHotbarViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoInventoryRules = require(CargoShared.Rules.CargoInventoryRules)
local CargoAppraisalFormulas = require(CargoShared.Utils.CargoAppraisalFormulas)
local ShiftCurrencyUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftCurrencyUtils)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

-- One hotbar slot (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md §4): slot 1 the vacuum
-- (its canister as the tag), slots 2-5 the item slots (an item's name and tag: its value once known, "$???" before,
-- "+N" clearance for trash; empty ones blank).
export type SlotView = {
	slot: number,
	-- The key that chooses it ("1"-"5").
	key: string,
	-- The item's kind (nil for the vacuum and an empty slot), drawn as its icon.
	kind: string?,
	name: string,
	tag: string,
	vacuum: boolean,
	empty: boolean,
	-- Chosen now: the vacuum out, the item in the hands, or an empty slot chosen with empty hands.
	selected: boolean,
	-- Its item is in the hands.
	inHands: boolean,
	-- Its item is the big one filling both hands: HANDS FULL.
	locked: boolean,
	-- A FRAGILE item (its tag in red).
	fragile: boolean,
}

export type HotbarView = {
	slots: { SlotView },
	-- A big item fills the hands: every slot is locked until it is dropped.
	locked: boolean,
	-- The chosen hotbar slot (0 = none).
	selected: number,
}

-- A hotbar card's measurements in HUD design px (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md
-- §4): the card, the gap between cards, how far the chosen card lifts, the sheet's padding, the art's size and top,
-- and the text sizes (key number, item name, tag, HANDS FULL stamp). A name size of 0 draws no name.
export type Metrics = {
	width: number,
	height: number,
	gap: number,
	lift: number,
	padding: number,
	icon: number,
	iconTop: number,
	key: number,
	name: number,
	tag: number,
	stamp: number,
}

-- Half the first hotbar's cards (96 x 112): the text stays at 12 px, readable, and the item name, which a 48 px card
-- cannot fit at a readable size, is left to the art (the HOLDING slip names the hands item).
local DESKTOP: Metrics = table.freeze({
	width = 48,
	height = 56,
	gap = 5,
	lift = 5,
	padding = 3,
	icon = 24,
	iconTop = 2,
	key = 12,
	name = 0,
	tag = 12,
	stamp = 11,
})
-- Half the first phone cards (62 x 70) would be 31 x 35, under a thumb's 44 px tap target, so a phone card stays
-- 44 px wide (and 48 tall): about 70% of before.
local PHONE: Metrics = table.freeze({
	width = 44,
	height = 48,
	gap = 4,
	lift = 5,
	padding = 3,
	icon = 22,
	iconTop = 2,
	key = 11,
	name = 0,
	tag = 11,
	stamp = 10,
})

local ShiftHotbarViewModel = {}

--[=[
	The hotbar card's measurements on phone or desktop (HUD design px).
]=]
function ShiftHotbarViewModel.metrics(phone: boolean): Metrics
	return if phone then PHONE else DESKTOP
end

--[=[
	The whole bar's size: `count` cards and the gaps between them wide, a card and its lift tall.
]=]
function ShiftHotbarViewModel.barSize(phone: boolean, count: number): Vector2
	local size = ShiftHotbarViewModel.metrics(phone)
	return Vector2.new(count * size.width + math.max(count - 1, 0) * size.gap, size.height + size.lift)
end

-- The hotbar slot chosen now: the hands item's, else the vacuum's when it is out, else the empty-hands choice.
local function chosenSlot(entry: PublicPlayerTypes.PublicPlayer): number
	local hands = entry[CargoConstants.PUBLIC_HANDS_FIELD]
	if type(hands) == "number" then
		return hands + 1
	end
	if entry[VacuumConstants.PUBLIC_EQUIPPED_FIELD] == true then
		return CargoConstants.VACUUM_SLOT
	end
	local selected = entry[CargoConstants.PUBLIC_SELECTED_FIELD]
	return if type(selected) == "number" and selected ~= CargoConstants.VACUUM_SLOT then selected else 0
end

--[=[
	The hotbar (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md §4) from the local player's
	public entry: the vacuum and the four item slots, which one is chosen, and whether a big hands item locks them.
]=]
function ShiftHotbarViewModel.hotbar(me: PublicPlayerTypes.PublicPlayer?): HotbarView
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local selected = chosenSlot(entry)
	local hands = entry[CargoConstants.PUBLIC_HANDS_FIELD]
	local fill = entry[VacuumConstants.PUBLIC_FIELD]
	local slots: { SlotView } = {
		{
			slot = CargoConstants.VACUUM_SLOT,
			key = tostring(CargoConstants.VACUUM_SLOT),
			kind = nil,
			name = "VACUUM",
			tag = `{if type(fill) == "number" then fill else 0}/{VacuumConstants.CANISTER_CAPACITY}`,
			vacuum = true,
			empty = false,
			selected = selected == CargoConstants.VACUUM_SLOT,
			inHands = false,
			locked = false,
			fragile = false,
		},
	}
	local locked = false
	for index, fields in CargoConstants.SLOT_FIELDS do
		local slot = index + 1
		local kind = entry[fields.kind]
		local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
		local inHands = hands == index and def ~= nil
		local big = inHands and def ~= nil and not CargoInventoryRules.isSmall(def)
		locked = locked or big
		local value = entry[fields.value]
		local variant = entry[fields.variant]
		local tag = ""
		local name = ""
		if def ~= nil then
			name = CargoAppraisalFormulas.displayName(def, if type(variant) == "string" then variant else nil, true)
			if def.category == "trash" then
				tag = `+{if type(value) == "number" then value else def.value}`
			elseif type(value) == "number" then
				tag = ShiftCurrencyUtils.amount(value)
			else
				tag = `{ShiftCurrencyUtils.SYMBOL}???`
			end
		end
		table.insert(slots, {
			slot = slot,
			key = tostring(slot),
			kind = if def ~= nil then def.id else nil,
			name = name,
			tag = tag,
			vacuum = false,
			empty = def == nil,
			selected = selected == slot,
			inHands = inHands,
			locked = big,
			fragile = def ~= nil and def.fragile,
		})
	end
	return { slots = slots, locked = locked, selected = selected }
end

return ShiftHotbarViewModel
