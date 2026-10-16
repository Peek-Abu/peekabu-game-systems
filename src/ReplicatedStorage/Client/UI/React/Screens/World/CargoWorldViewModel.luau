--!strict
--[=[
	CargoWorldViewModel: what a cargo item's price tag says and when it is drawn (Figma World UI 2b, W5). The tag reads
	the item's shell attributes (CargoConstants.LABEL_KEYS): the name (cut at NAME_MAX, the longest catalog name, so
	every real name stays whole), the price ("$45" for a Recoverable Asset, ShiftCurrencyUtils; "+10" clearance for trash) and the mark: "FRAGILE" for an
	undamaged fragile item, "CRACKED −50%" / "CRACKED −75%" from CargoConstants.FRAGILE_TIERS once it took impacts
	(the price turns red), else none. A grimy valuable (the loot loop, docs/superpowers/specs/
	2026-10-15-cleanup-crew-loot-loop-design.md §5) reads "$???" until appraised, its mark leads with how clean it is
	("62% CLEAN", joined with the fragile mark; "GRIME LOCKED 62%" once its grime is locked, picked up dirty), and once
	appraised it carries the APPRAISED stamp, which pops while the appraisal is fresh. `mounted`: a tag mounts within LABEL_DISTANCE of the camera and stays until
	LABEL_KEEP_DISTANCE, and never while the item is hidden under a pile.
	The load floaters (W6): clearance pops as the number over CLEARED, the pay earned as a "+$40" stamp (the
	approved frame's layout). Pure.

	@class CargoWorldViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoFeedbackUtils = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoFeedbackUtils)
local ShiftCurrencyUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftCurrencyUtils)
local CargoLootFeedbackFormulas = require(ReplicatedStorage.Client.Features.Cargo.Utils.CargoLootFeedbackFormulas)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

export type PriceTagView = {
	name: string,
	price: string,
	-- A fragile item that took impacts: the price is drawn in stamp red.
	cracked: boolean,
	mark: string?,
	-- A valuable whose value is revealed: it wears the APPRAISED stamp, which pops in while fresh.
	appraised: boolean,
	pop: boolean,
}

export type FloaterView = {
	-- The pay earned: drawn as the blue stamp.
	bonus: boolean,
	text: string,
	caption: string?,
}

local CargoWorldViewModel = {}

-- utf8.len("Employee of the Month plaque"), the longest catalog name.
CargoWorldViewModel.NAME_MAX = 28

local function markOf(fragile: boolean, impacts: number): string?
	if not fragile then
		return nil
	end
	if impacts == 0 then
		return "FRAGILE"
	end
	local tiers = CargoConstants.FRAGILE_TIERS
	local fraction = tiers[math.clamp(impacts + 1, 1, #tiers)]
	return `CRACKED −{math.floor((1 - fraction) * 100 + 0.5)}%`
end

-- "62% CLEAN": a grimy valuable's cleanliness, rounded down so it reads 100% only when spotless; nil once spotless.
-- "GRIME LOCKED 62%" once its grime is locked (it can never be cleaned again).
local function cleanMark(clean: number, sealed: boolean): string?
	if clean >= 1 then
		return nil
	end
	local percent = math.floor(math.clamp(clean, 0, 1) * 100)
	return if sealed then `GRIME LOCKED {percent}%` else `{percent}% CLEAN`
end

--[=[
	The tag for an item's shell `attributes`; `now` (server time) decides whether a fresh appraisal's stamp pops.
]=]
function CargoWorldViewModel.priceTag(attributes: { [string]: unknown }, now: number?): PriceTagView?
	local keys = CargoConstants.LABEL_KEYS
	local name = attributes[keys.name]
	local value = attributes[keys.value]
	if type(name) ~= "string" or type(value) ~= "number" or value ~= value then
		return nil
	end
	local fragile = attributes[keys.fragile] == true
	local rawImpacts = attributes[keys.impacts]
	local impacts = if type(rawImpacts) == "number" then math.max(0, math.floor(rawImpacts)) else 0
	local whole = math.max(0, math.floor(value + 0.5))
	local grimy = attributes[keys.grimy] == true
	local appraised = grimy and attributes[keys.appraised] == true
	local rawClean = attributes[keys.clean]
	local clean = if type(rawClean) == "number" then rawClean else 1
	local appraisedAt = attributes[keys.appraisedAt]
	local marks: { string } = {}
	local grime = if grimy then cleanMark(clean, attributes[keys.sealed] == true) else nil
	if grime ~= nil then
		table.insert(marks, grime)
	end
	local fragileMark = markOf(fragile, impacts)
	if fragileMark ~= nil then
		table.insert(marks, fragileMark)
	end
	local price = if attributes[keys.category] == "salvage" then ShiftCurrencyUtils.amount(whole) else `+{whole}`
	return {
		name = WorldBillboardViewModel.clip(name, CargoWorldViewModel.NAME_MAX),
		price = if grimy and not appraised then `{ShiftCurrencyUtils.SYMBOL}???` else price,
		cracked = fragile and impacts > 0,
		mark = if #marks > 0 then table.concat(marks, " · ") else nil,
		appraised = appraised,
		pop = appraised
			and now ~= nil
			and CargoLootFeedbackFormulas.stampFresh(if type(appraisedAt) == "number" then appraisedAt else nil, now),
	}
end

function CargoWorldViewModel.mounted(distance: number, mountedNow: boolean, hidden: boolean): boolean
	if hidden then
		return false
	end
	if mountedNow then
		return distance <= CargoConstants.LABEL_KEEP_DISTANCE
	end
	return distance <= CargoConstants.LABEL_DISTANCE
end

function CargoWorldViewModel.floater(item: CargoFeedbackUtils.Floater): FloaterView
	if item.tone == "bonus" then
		return { bonus = true, text = ShiftCurrencyUtils.signed(item.text), caption = nil }
	end
	return { bonus = false, text = item.text, caption = "CLEARED" }
end

return CargoWorldViewModel
