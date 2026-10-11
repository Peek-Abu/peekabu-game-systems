--!strict
--[=[
	CargoWorldViewModel: what a cargo item's price tag says and when it is drawn (Figma World UI 2b, W5). The tag reads
	the item's shell attributes (CargoConstants.LABEL_KEYS): the name (cut at NAME_MAX, the longest catalog name, so
	every real name stays whole), the price ("$45" for salvage, "+10" clearance for trash) and the mark: "FRAGILE" for an
	undamaged fragile item, "CRACKED −50%" / "CRACKED −75%" from CargoConstants.FRAGILE_TIERS once it took impacts
	(the price turns red), else none. `mounted`: a tag mounts within LABEL_DISTANCE of the camera and stays until
	LABEL_KEEP_DISTANCE, and never while the item is hidden under a pile.
	The load floaters (W6): clearance pops as the number over CLEARED, the finder's fee as a "+40 BONUS" stamp (the
	approved frame's copy). Pure.

	@class CargoWorldViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoFeedbackUtils = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoFeedbackUtils)
local WorldBillboardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.WorldBillboardViewModel)

export type PriceTagView = {
	name: string,
	price: string,
	-- A fragile item that took impacts: the price is drawn in stamp red.
	cracked: boolean,
	mark: string?,
}

export type FloaterView = {
	-- The finder's fee: drawn as the blue stamp.
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

function CargoWorldViewModel.priceTag(attributes: { [string]: unknown }): PriceTagView?
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
	return {
		name = WorldBillboardViewModel.clip(name, CargoWorldViewModel.NAME_MAX),
		price = if attributes[keys.category] == "salvage" then `${whole}` else `+{whole}`,
		cracked = fragile and impacts > 0,
		mark = markOf(fragile, impacts),
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
		return { bonus = true, text = `{item.text} BONUS`, caption = nil }
	end
	return { bonus = false, text = item.text, caption = "CLEARED" }
end

return CargoWorldViewModel
