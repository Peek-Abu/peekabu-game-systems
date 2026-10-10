--!strict
--[=[
	OfficeSpawnUtils: rolls one shift's spawns onto the layout's markers (Cleanup Crew spec §4 "Spawn
	guarantees", §1 "randomised spawns"). Deterministic for a given Random: the catalog is walked in sorted
	order and `rng` is consumed in a fixed sequence:

	1. piles: a count in `options.piles`, on shuffled pile markers, each a random pile kind;
	2. desks and lockers: each holds a desk-weighted item with SEARCH_FILL_CHANCE, else nothing;
	3. the greed target (fish tank, filing cabinet or golden stapler), always in a deep room: a hidden one
	   (the stapler) in a deep desk or locker (else under a deep pile), the others on a deep item marker;
	4. salvage: a count in `options.salvage`; in variant "B" a hideable one may go under a free pile;
	5. trash on the remaining item markers until the floor's trash (plus the piles' dust bags) reaches
	   TRASH_FACTOR × quota.

	OfficeSpawnRules.check verifies the result. Pure.

	@class OfficeSpawnUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeSpawnRules = require(OfficeServer.Rules.OfficeSpawnRules)

type Marker = OfficeTypes.Marker
type ItemDef = CargoTypes.ItemDef

local function shuffled(list: { Marker }, rng: Random): { Marker }
	local copy = table.clone(list)
	for index = #copy, 2, -1 do
		local swap = rng:NextInteger(1, index)
		copy[index], copy[swap] = copy[swap], copy[index]
	end
	return copy
end

-- A catalog id chosen by weight; nil when every weight is 0.
local function pickWeighted(weightOf: (def: ItemDef) -> number, rng: Random): string?
	local total = 0
	local last: string? = nil
	for _, id in CargoRegistry.ids() do
		local def = CargoRegistry.get(id)
		local weight = if def ~= nil then weightOf(def) else 0
		if weight > 0 then
			total += weight
			last = id
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, id in CargoRegistry.ids() do
		local def = CargoRegistry.get(id)
		local weight = if def ~= nil then weightOf(def) else 0
		if weight > 0 then
			if roll < weight then
				return id
			end
			roll -= weight
		end
	end
	return last
end

local function trashWeight(def: ItemDef): number
	return if def.category == "trash" then def.spawnWeight else 0
end

local function salvageWeight(def: ItemDef): number
	return if def.category == "salvage" and not def.greed and not def.hidden then def.spawnWeight else 0
end

local function deskWeight(def: ItemDef): number
	return if def.greed then 0 else def.deskWeight
end

local OfficeSpawnUtils = {}

function OfficeSpawnUtils.roll(
	layout: OfficeTypes.Layout,
	options: OfficeTypes.RollOptions,
	rng: Random
): OfficeTypes.SpawnPlan
	local depths = OfficeLayoutUtils.depths(layout)
	local function isDeep(marker: Marker): boolean
		return (depths[marker.room] or 0) >= OfficeConstants.DEEP_DEPTH
	end

	-- 1. Piles.
	local pileMarkers = shuffled(OfficeLayoutUtils.markersOf(layout, "pile"), rng)
	local pileCount = math.min(rng:NextInteger(options.piles.min, options.piles.max), #pileMarkers)
	local kinds = VacuumConstants.PILE_KIND_LIST
	local piles: { OfficeTypes.PilePlan } = {}
	for index = 1, pileCount do
		table.insert(piles, { marker = pileMarkers[index].id, kind = kinds[rng:NextInteger(1, #kinds)] })
	end
	local function freePile(deepOnly: boolean): OfficeTypes.PilePlan?
		for index, pile in piles do
			if pile.hides == nil and (not deepOnly or isDeep(pileMarkers[index])) then
				return pile
			end
		end
		return nil
	end

	-- 2. Desks and lockers, in layout order.
	local searchMarkers = OfficeLayoutUtils.markersOf(layout, "desk")
	for _, marker in OfficeLayoutUtils.markersOf(layout, "locker") do
		table.insert(searchMarkers, marker)
	end
	local searchables: { OfficeTypes.SearchPlan } = {}
	for _, marker in searchMarkers do
		local kind = if rng:NextNumber() < OfficeConstants.SEARCH_FILL_CHANCE
			then pickWeighted(deskWeight, rng)
			else nil
		table.insert(searchables, { marker = marker.id, kind = kind })
	end

	local itemPool = shuffled(OfficeLayoutUtils.markersOf(layout, "item"), rng)
	local items: { OfficeTypes.ItemPlan } = {}
	local function takeMarker(deepOnly: boolean): Marker?
		for index, marker in itemPool do
			if not deepOnly or isDeep(marker) then
				table.remove(itemPool, index)
				return marker
			end
		end
		return nil
	end

	-- 3. The greed target, deep.
	local greedIds = CargoRegistry.greedIds()
	local greedKind = greedIds[rng:NextInteger(1, #greedIds)]
	local greedDef = CargoRegistry.get(greedKind)
	local greed: OfficeTypes.ItemPlan? = nil
	if greedDef ~= nil and greedDef.hidden then
		local deepSearch: { number } = {}
		for index, marker in searchMarkers do
			if isDeep(marker) then
				table.insert(deepSearch, index)
			end
		end
		if #deepSearch > 0 then
			local index = deepSearch[rng:NextInteger(1, #deepSearch)]
			searchables[index].kind = greedKind
			greed = { marker = searchMarkers[index].id, kind = greedKind }
		else
			local pile = freePile(true)
			if pile ~= nil then
				pile.hides = greedKind
				greed = { marker = pile.marker, kind = greedKind }
			end
		end
	else
		local marker = takeMarker(true)
		if marker ~= nil then
			local placed: OfficeTypes.ItemPlan = { marker = marker.id, kind = greedKind }
			greed = placed
			table.insert(items, placed)
		end
	end

	-- 4. Salvage.
	local salvageCount = rng:NextInteger(options.salvage.min, options.salvage.max)
	for _ = 1, salvageCount do
		local kind = pickWeighted(salvageWeight, rng)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if kind == nil or def == nil then
			break
		end
		local hideable = options.variant == "B" and OfficeConstants.HIDEABLE[def.size] == true
		local pile = if hideable and rng:NextNumber() < OfficeConstants.HIDE_CHANCE then freePile(false) else nil
		if pile ~= nil then
			pile.hides = kind
		else
			local marker = takeMarker(false)
			if marker == nil then
				break
			end
			table.insert(items, { marker = marker.id, kind = kind })
		end
	end

	-- 5. Trash until the guarantee.
	local trashValue = OfficeSpawnRules.pileTrash(pileCount)
	local target = options.quota * OfficeConstants.TRASH_FACTOR
	while trashValue < target do
		local kind = pickWeighted(trashWeight, rng)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		local marker = takeMarker(false)
		if kind == nil or def == nil or marker == nil then
			break
		end
		table.insert(items, { marker = marker.id, kind = kind })
		trashValue += def.value
	end

	return {
		piles = piles,
		items = items,
		searchables = searchables,
		greed = greed,
		trashValue = trashValue,
	}
end

return OfficeSpawnUtils
