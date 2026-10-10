--!strict
--[=[
	CargoHandlingRules: what handling does to cargo (Cleanup Crew spec §4). Pockets take tiny items only,
	two at a time; a fragile item loses a value tier per impact; a recycling box spills into a pile; a drop
	is as loud as the item is heavy, and the water jug splashes louder than anything. Pure.

	@class CargoHandlingRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryTypes = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type ItemDef = CargoTypes.ItemDef

local CargoHandlingRules = {}

--[=[
	Whether the hands item fits a pocket, given how many are already pocketed.
]=]
function CargoHandlingRules.canPocket(def: ItemDef?, pocketed: number): (boolean, string?)
	if def == nil then
		return false, "not cargo"
	end
	if def.size ~= CargoConstants.POCKET_SIZE then
		return false, "too big for pockets"
	end
	if pocketed >= CargoConstants.POCKET_SLOTS then
		return false, "pockets full"
	end
	return true, nil
end

--[=[
	An item's value after `impacts` drops or throws: unchanged unless fragile, else the catalog value times
	the tier's fraction, rounded; past the last tier it stays there.
]=]
function CargoHandlingRules.valueAfter(def: ItemDef, impacts: number): number
	if not def.fragile then
		return def.value
	end
	local tiers = CargoConstants.FRAGILE_TIERS
	local fraction = tiers[math.clamp(impacts + 1, 1, #tiers)]
	return math.floor(def.value * fraction + 0.5)
end

--[=[
	Whether a hold ending for `reason` hit the floor. Everything does except the object being destroyed while
	held. (Cargo's own pocketing and banking claim the item first, so their forced drops never get here.)
]=]
function CargoHandlingRules.isImpact(reason: CarryTypes.DropReason): boolean
	return reason ~= "destroyed"
end

function CargoHandlingRules.shouldSpill(def: ItemDef, reason: CarryTypes.DropReason): boolean
	return def.spills and CargoHandlingRules.isImpact(reason)
end

--[=[
	The radius (studs) a drop of this item is heard at (the M2 Noise seam).
]=]
function CargoHandlingRules.dropNoise(def: ItemDef): number
	if def.splashes then
		return CargoConstants.SPLASH_NOISE
	end
	return CargoConstants.DROP_NOISE[def.size] or 0
end

--[=[
	What a swap request does (spec §6.3): with empty hands the newest pocketed item comes out ("unpocket"); with
	a tiny item in hand it goes into the pockets and the oldest pocketed item comes out ("swap"). Nil with a
	reason when the pockets are empty or the hands hold anything bigger (or not cargo).
]=]
function CargoHandlingRules.swapPlan(
	holding: boolean,
	def: ItemDef?,
	pocketed: number
): (CargoTypes.SwapAction?, string?)
	if pocketed <= 0 then
		return nil, "pockets empty"
	end
	if not holding then
		return "unpocket", nil
	end
	if def == nil or def.size ~= CargoConstants.POCKET_SIZE then
		return nil, "hands full"
	end
	return "swap", nil
end

return CargoHandlingRules
