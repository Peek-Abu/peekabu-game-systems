--!strict
--[=[
	ShiftHotbarViewModel: what the paper hotbar (ShiftHotbar) shows, from the local player's public entry
	(docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md §4): the vacuum in slot 1 with its
	canister gauge (the crew's contract, Gloom removed of the contract: docs/superpowers/specs/
	2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §5), the four item slots with each item's name and tag, which slot is chosen, and whether a big hands item locks
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
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

-- One hotbar slot (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md §4): slot 1 the vacuum
-- (the contract's progress as the tag, "340/500"), slots 2-5 the item slots (an item's name and tag: its Gleam once
-- known, "??? Gleam" before, "+N" for trash; empty ones blank).
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
	-- V1: the vacuum's Gloom gauge (0..1 of the contract; nil without one) and the short caption a slot's pill shows
	-- ("58%", a valuable's worth "220" or "???" with the coin, trash "+10"; nil for an empty slot).
	gauge: number?,
	caption: string?,
	coin: boolean,
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

-- The kit renders (UIAssets.toonIcons) of the cargo kinds that have one; the rest draw their live model.
local ICONS: { [string]: UIAssets.ToonIcon } = {}
ICONS.monitor = "monitor"
ICONS.fishTank = "fishtank"
ICONS.goldenStapler = "stapler"
ICONS.snowGlobe = "globe"
ICONS.keyring = "key"

function ShiftHotbarViewModel.iconFor(kind: string): UIAssets.ToonIcon?
	return ICONS[kind]
end

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
	`cleared` and `quota` are the shift's Gloom removed and contract (the vacuum's tag; blank without a contract).
]=]
function ShiftHotbarViewModel.hotbar(me: PublicPlayerTypes.PublicPlayer?, cleared: number?, quota: number?): HotbarView
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local selected = chosenSlot(entry)
	local hands = entry[CargoConstants.PUBLIC_HANDS_FIELD]
	local gauge = if quota ~= nil and quota > 0 then math.clamp(math.floor(cleared or 0) / quota, 0, 1) else nil
	local slots: { SlotView } = {
		{
			gauge = gauge,
			caption = if gauge ~= nil then `{math.floor(gauge * 100 + 0.5)}%` else nil,
			coin = false,
			slot = CargoConstants.VACUUM_SLOT,
			key = tostring(CargoConstants.VACUUM_SLOT),
			kind = nil,
			name = "VACUUM",
			tag = if quota ~= nil and quota > 0 then `{math.floor(cleared or 0)}/{quota}` else "",
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
		local caption: string? = nil
		local coin = false
		if def ~= nil then
			name = CargoAppraisalFormulas.displayName(def, if type(variant) == "string" then variant else nil, true)
			if def.category == "trash" then
				tag = `+{if type(value) == "number" then value else def.value}`
				caption = tag
			elseif type(value) == "number" then
				tag = ShiftCurrencyUtils.amount(value)
				caption = tostring(math.floor(value))
				coin = true
			else
				tag = ShiftCurrencyUtils.unknown()
				caption = "???"
				coin = true
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
			gauge = nil,
			caption = caption,
			coin = coin,
		})
	end
	return { slots = slots, locked = locked, selected = selected }
end

return ShiftHotbarViewModel
