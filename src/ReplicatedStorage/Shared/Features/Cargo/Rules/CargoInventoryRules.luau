--!strict
--[=[
	CargoInventoryRules: the hotbar inventory's rules (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md).
	Five hotbar slots: slot 1 the vacuum, slots 2-5 four item slots. E on a small item (tiny / light) pockets it into
	a free item slot without touching the hands; E on a big one takes a free slot and both hands, and a big item in the
	hands locks the hotbar (no switching, no vacuum, no other pick-up) until it is dropped. Choosing a slot draws its
	small item into one hand (the hands item goes back to its own slot first). The load a player carries is the big
	item's weight plus SMALL_LOAD per small item. Pure.

	@class CargoInventoryRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type ItemDef = CargoTypes.ItemDef

local CargoInventoryRules = {}

--[=[
	Whether an item is small: pocketed on pick-up, held in one hand.
]=]
function CargoInventoryRules.isSmall(def: ItemDef): boolean
	return CargoConstants.SMALL_SIZES[def.size] == true
end

--[=[
	Whether the hands leave pick-ups open (the prompts a client offers): empty (`held` nil), or holding a small cargo
	kind in one hand. A big item, or anything that is not cargo, closes them.
]=]
function CargoInventoryRules.handsFree(held: string?): boolean
	if held == nil then
		return true
	end
	local def = CargoRegistry.get(held)
	return def ~= nil and CargoInventoryRules.isSmall(def)
end

--[=[
	What pressing E on a cargo item does: "pocket" a small one, "hold" a big one; nil with a reason when a big item
	already fills the hands, every item slot is full (`free` nil), or it is not cargo.
]=]
function CargoInventoryRules.pickUpPlan(
	def: ItemDef?,
	free: number?,
	handsBig: boolean
): (CargoTypes.PickUpPlan?, string?)
	if def == nil then
		return nil, "not cargo"
	end
	if handsBig then
		return nil, "hands full"
	end
	if free == nil then
		return nil, "inventory full"
	end
	return if CargoInventoryRules.isSmall(def) then "pocket" else "hold", nil
end

--[=[
	What choosing hotbar slot `target` (1-5) does. Choosing the slot already chosen puts away what it holds (the vacuum,
	or the hands item back into its slot), leaving nothing chosen. Nil with a reason while a big item locks the hands, or
	for a slot that does not exist.
]=]
function CargoInventoryRules.selectPlan(
	target: number,
	hotbar: CargoTypes.HotbarState
): (CargoTypes.SelectPlan?, string?)
	if target ~= math.floor(target) or target < 1 or target > CargoConstants.HOTBAR_SLOTS then
		return nil, "no such slot"
	end
	if hotbar.handsBig then
		return nil, "hands full: drop it first"
	end
	local holding = hotbar.hands ~= nil
	if target == CargoConstants.VACUUM_SLOT then
		local again = hotbar.selected == target and not holding
		return { stash = holding, draw = nil, vacuum = not again, selected = if again then 0 else target }, nil
	end
	local item = target - 1
	if hotbar.hands == item then
		return { stash = true, draw = nil, vacuum = false, selected = 0 }, nil
	end
	return {
		stash = holding,
		draw = if hotbar.filled[item] == true then item else nil,
		vacuum = false,
		selected = target,
	},
		nil
end

--[=[
	The hotbar slot one step (`direction` +1 next, -1 previous) from `current`, wrapping round; from nothing chosen (0)
	the first or the last.
]=]
function CargoInventoryRules.step(current: number, direction: number): number
	local count = CargoConstants.HOTBAR_SLOTS
	if current < 1 or current > count then
		return if direction >= 0 then 1 else count
	end
	return (current - 1 + (if direction >= 0 then 1 else -1)) % count + 1
end

--[=[
	The load a player carries: SMALL_LOAD per small item in their inventory (pocketed or in one hand) plus the weight of
	the big item in their hands (`big`; a small kind given here counts nothing extra).
]=]
function CargoInventoryRules.load(smallCount: number, big: ItemDef?): number
	local weight = if big ~= nil and not CargoInventoryRules.isSmall(big)
		then CargoConstants.WEIGHT[big.size] or 0
		else 0
	return smallCount * CargoConstants.SMALL_LOAD + weight
end

return CargoInventoryRules
