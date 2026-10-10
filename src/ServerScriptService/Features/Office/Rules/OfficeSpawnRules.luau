--!strict
--[=[
	OfficeSpawnRules: does one shift's spawn plan keep the spec's promises (§4 "Spawn guarantees")? Trash on
	the floor, counting the dust bags the piles make, is at least TRASH_FACTOR × the quota; one greed target
	sits in a deep room; no marker holds two things. Pure.

	@class OfficeSpawnRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

type SpawnPlan = OfficeTypes.SpawnPlan

local OfficeSpawnRules = {}

--[=[
	The trash the dust bags of `pileCount` piles come to: one bag per full canister.
]=]
function OfficeSpawnRules.pileTrash(pileCount: number): number
	local dustBag = CargoRegistry.get(VacuumConstants.DUST_BAG_KIND)
	local bags = math.floor(pileCount / VacuumConstants.CANISTER_CAPACITY)
	return bags * (if dustBag ~= nil then dustBag.value else 0)
end

--[=[
	The clearance a plan puts on the floor: open-floor trash items plus one dust bag per full canister of
	piles. Unknown kinds count nothing (`check` refuses them).
]=]
function OfficeSpawnRules.trashValue(plan: SpawnPlan): number
	local total = OfficeSpawnRules.pileTrash(#plan.piles)
	for _, item in plan.items do
		local def = CargoRegistry.get(item.kind)
		if def ~= nil and def.category == "trash" then
			total += def.value
		end
	end
	return total
end

--[=[
	Ok when `plan` meets every guarantee for `quota`; otherwise the first broken one.
]=]
function OfficeSpawnRules.check(plan: SpawnPlan, layout: OfficeTypes.Layout, quota: number): (boolean, string?)
	local used: { [string]: boolean } = {}
	local markers: { string } = {}
	for _, pile in plan.piles do
		table.insert(markers, pile.marker)
	end
	for _, item in plan.items do
		if CargoRegistry.get(item.kind) == nil then
			return false, `unknown cargo "{item.kind}"`
		end
		table.insert(markers, item.marker)
	end
	for _, marker in markers do
		if used[marker] then
			return false, `marker "{marker}" is used twice`
		end
		used[marker] = true
	end

	local trash = OfficeSpawnRules.trashValue(plan)
	if trash < quota * OfficeConstants.TRASH_FACTOR then
		return false, `only {trash} trash for a quota of {quota}`
	end

	local greed = plan.greed
	if greed == nil then
		return false, "no greed target"
	end
	local def = CargoRegistry.get(greed.kind)
	if def == nil or not def.greed then
		return false, `"{greed.kind}" is not a greed target`
	end
	local marker = OfficeLayoutUtils.marker(layout, greed.marker)
	local depths = OfficeLayoutUtils.depths(layout)
	if marker == nil or (depths[marker.room] or 0) < OfficeConstants.DEEP_DEPTH then
		return false, "the greed target is not placed deep"
	end
	return true, nil
end

return OfficeSpawnRules
