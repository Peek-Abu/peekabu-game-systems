--!strict
--[=[
	CargoInventoryUtils: the hotbar inventory's public fields (docs/superpowers/specs/2026-10-16-cleanup-crew-hotbar-inventory-design.md
	§3) from a player's slots: each item slot's kind, its value once known (trash always, a valuable once appraised) and
	an appraised jackpot's name, the item slot in the hands and the hotbar slot chosen with empty hands. What to set and
	what to clear. Pure.

	@class CargoInventoryUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)

type CargoEntry = CargoTypes.CargoEntry

export type Published = { set: { [string]: string | number | boolean }, cleared: { string } }

local CargoInventoryUtils = {}

--[=[
	An entry's price as the hotbar shows it: trash always, a valuable once appraised (nil = "$???").
]=]
function CargoInventoryUtils.knownValue(entry: CargoEntry): number?
	local appraisal = entry.appraisal
	if appraisal == nil then
		return entry.value
	end
	return if appraisal.appraised then entry.value else nil
end

--[=[
	The fields to set and the fields to clear for item `slots` (by slot 1-4), the item slot in the hands (nil = none)
	and the empty-hands choice (0 = none).
]=]
function CargoInventoryUtils.published(slots: { [number]: CargoEntry }, hands: number?, selected: number): Published
	local set: { [string]: string | number | boolean } = {}
	local cleared: { string } = {}
	local function put(field: string, value: (string | number)?)
		if value ~= nil then
			set[field] = value
		else
			table.insert(cleared, field)
		end
	end
	for index, names in CargoConstants.SLOT_FIELDS do
		local entry = slots[index]
		local appraisal = if entry ~= nil then entry.appraisal else nil
		put(names.kind, if entry ~= nil then entry.kind else nil)
		put(names.value, if entry ~= nil then CargoInventoryUtils.knownValue(entry) else nil)
		put(names.variant, if appraisal ~= nil and appraisal.appraised then appraisal.variant else nil)
	end
	put(CargoConstants.PUBLIC_HANDS_FIELD, hands)
	put(CargoConstants.PUBLIC_SELECTED_FIELD, if selected > 0 then selected else nil)
	return { set = set, cleared = cleared }
end

return CargoInventoryUtils
