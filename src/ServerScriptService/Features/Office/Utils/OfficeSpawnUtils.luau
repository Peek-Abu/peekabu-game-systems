--!strict
--[=[
	OfficeSpawnUtils: rolls one shift's spawns onto the layout's markers (Cleanup Crew spec §4 "Spawn
	guarantees", §1 "randomised spawns"; the loot loop, docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md
	§3.5). Deterministic for a given Random: the catalog is walked in sorted order and `rng` is consumed in a fixed
	sequence:

	1. piles: a count in `options.piles`, on shuffled pile markers, each a random pile kind;
	2. desks and lockers: each holds a desk-weighted valuable with SEARCH_FILL_CHANCE, else nothing; after
	   DESK_VALUABLES_MAX valuables, nothing;
	3. the greed target (fish tank, filing cabinet or golden stapler), always in a deep room: a hidden one
	   (the stapler) in a deep desk or locker (else under a deep pile), the others on a deep item marker;
	4. the valuables budget, a count in `options.valuables` that the greed target and desk valuables count toward;
	5. buried loot: one BURY_CHANCE draw per pile (OfficeLootUtils.buried), each hit burying a buriable valuable,
	   capped so MIN_OPEN of the budget is left for the open;
	6. the rest of the budget in the open (on item markers, or the furniture tops their kind belongs on);
	7. the top-up: plain piles on free pile markers, at most TOP_UP_MAX, while the site's Gloom is too thin for the
	   contract (`options.quota`, OfficeLootUtils.shortfall; docs/superpowers/specs/
	   2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §3.4).

	Every valuable is appraised as it is placed (CargoAppraisalFormulas.roll, scaled by its marker's depth). No trash
	is rolled: it counts toward nothing under the Gloom contract. The A/B variant no longer changes the roll.
	OfficeSpawnRules.check verifies the result. Pure.

	@class OfficeSpawnUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local CargoAppraisalFormulas = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoAppraisalFormulas)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeLootUtils = require(OfficeServer.Utils.OfficeLootUtils)
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

local function salvageWeight(def: ItemDef): number
	return if def.category == "salvage" and not def.greed and not def.hidden then def.spawnWeight else 0
end

local function buriedWeight(def: ItemDef): number
	return if def.buriable then def.spawnWeight else 0
end

local function deskWeight(def: ItemDef): number
	return if def.greed or not def.grimy then 0 else def.deskWeight
end

-- The surface marker kinds loot of this def belongs on, in preference order; empty for the floor.
local function surfaceFor(def: ItemDef): { string }
	return OfficeSpawnRules.surfaceKindsFor(def.id)
end

local OfficeSpawnUtils = {}

function OfficeSpawnUtils.roll(
	layout: OfficeTypes.Layout,
	options: OfficeTypes.RollOptions,
	rng: Random
): OfficeTypes.SpawnPlan
	local depths = OfficeLayoutUtils.depths(layout)
	local function depthOf(marker: Marker): number
		return depths[marker.room] or 0
	end
	local function isDeep(marker: Marker): boolean
		return depthOf(marker) >= OfficeConstants.DEEP_DEPTH
	end
	-- A valuable's rolled appraisal where `marker` stands (nil for trash: it has a fixed price).
	local function appraise(kind: string?, marker: Marker): CargoTypes.AppraisalRoll?
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if def == nil or not def.grimy then
			return nil
		end
		local roll = CargoAppraisalFormulas.roll(def, depthOf(marker), rng)
		return roll
	end

	-- 1. Piles.
	local pileMarkers = shuffled(OfficeLayoutUtils.markersOf(layout, "pile"), rng)
	local pileCount = math.min(rng:NextInteger(options.piles.min, options.piles.max), #pileMarkers)
	local kinds = VacuumConstants.PILE_KIND_LIST
	local piles: { OfficeTypes.PilePlan } = {}
	for index = 1, pileCount do
		table.insert(piles, { marker = pileMarkers[index].id, kind = kinds[rng:NextInteger(1, #kinds)] })
	end
	local function freePile(deepOnly: boolean): number?
		for index, pile in piles do
			if pile.hides == nil and (not deepOnly or isDeep(pileMarkers[index])) then
				return index
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
	local deskValuables = 0
	for _, marker in searchMarkers do
		local full = deskValuables >= OfficeConstants.DESK_VALUABLES_MAX
		local kind = if rng:NextNumber() < OfficeConstants.SEARCH_FILL_CHANCE and not full
			then pickWeighted(deskWeight, rng)
			else nil
		local appraisal = appraise(kind, marker)
		if appraisal ~= nil then
			deskValuables += 1
		end
		table.insert(searchables, { marker = marker.id, kind = kind, appraisal = appraisal })
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

	-- Surface tops: one reservation per piece, preferred kind first. Floor-capable loot can overflow;
	-- appliances are excluded from the draw when no eligible top remains.
	local surfaces = {}
	for _, marker in layout.markers do
		if OfficeLayoutUtils.surfaceTopY(marker.kind) ~= nil then
			table.insert(surfaces, marker)
		end
	end
	local function surfaceIndex(itemId: string, deepOnly: boolean): number?
		for _, wanted in OfficeSpawnRules.surfaceKindsFor(itemId) do
			for index, marker in surfaces do
				if marker.kind == wanted and (not deepOnly or isDeep(marker)) then
					return index
				end
			end
		end
		return nil
	end
	local function takeSurface(itemId: string, deepOnly: boolean): Marker?
		local index = surfaceIndex(itemId, deepOnly)
		return if index ~= nil then table.remove(surfaces, index) else nil
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
			local search = searchables[index]
			if search.appraisal ~= nil then
				deskValuables -= 1
			end
			search.kind = greedKind
			search.appraisal = appraise(greedKind, searchMarkers[index])
			greed = { marker = searchMarkers[index].id, kind = greedKind }
		else
			local index = freePile(true)
			if index ~= nil then
				piles[index].hides = greedKind
				piles[index].appraisal = appraise(greedKind, pileMarkers[index])
				greed = { marker = piles[index].marker, kind = greedKind }
			end
		end
	else
		local placed: OfficeTypes.ItemPlan? = nil
		local spot: Marker? = nil
		if greedDef ~= nil and #surfaceFor(greedDef) > 0 then
			spot = takeSurface(greedKind, true)
		end
		if spot == nil then
			spot = takeMarker(true)
		end
		if spot ~= nil then
			placed = { marker = spot.id, kind = greedKind, appraisal = appraise(greedKind, spot) }
		end
		if placed ~= nil then
			greed = placed
			table.insert(items, placed)
		end
	end

	-- 4. The valuables budget: the greed target and the desks' valuables count toward it.
	local budget = rng:NextInteger(options.valuables.min, options.valuables.max)
	local placedCount = (if greed ~= nil then 1 else 0) + deskValuables

	-- 5. Buried loot: a buriable valuable under each pile whose draw hits, leaving MIN_OPEN for the open.
	local room = math.max(0, budget - placedCount - OfficeConstants.MIN_OPEN)
	for _, index in OfficeLootUtils.buried(pileCount, room, rng) do
		local pile = piles[index]
		local kind = pickWeighted(buriedWeight, rng)
		if pile.hides == nil and kind ~= nil then
			pile.hides = kind
			pile.appraisal = appraise(kind, pileMarkers[index])
			placedCount += 1
		end
	end

	-- 6. One valuable in the open: a weighted kind, on a top its kind belongs on, else an item marker. False when the
	-- markers ran out.
	local function placeOpen(): boolean
		local kind = pickWeighted(function(def)
			-- Re-roll from eligible valuables with the same single weighted draw: never dump appliances on the floor.
			return if OfficeSpawnRules.requiresSurface(def.id) and surfaceIndex(def.id, false) == nil
				then 0
				else salvageWeight(def)
		end, rng)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if kind == nil or def == nil then
			return false
		end
		local spot = if #surfaceFor(def) > 0 then takeSurface(kind, false) else nil
		if spot == nil then
			spot = takeMarker(false)
		end
		if spot == nil then
			return false
		end
		table.insert(items, { marker = spot.id, kind = kind, appraisal = appraise(kind, spot) })
		return true
	end
	while placedCount < budget and placeOpen() do
		placedCount += 1
	end

	local plan: OfficeTypes.SpawnPlan = {
		piles = piles,
		items = items,
		searchables = searchables,
		greed = greed,
		value = 0,
	}
	-- 7. The top-up: a site too thin in Gloom for the contract gets a few more plain piles.
	local topped = 0
	while
		topped < OfficeConstants.TOP_UP_MAX
		and #piles < #pileMarkers
		and OfficeLootUtils.shortfall(plan, options.quota)
	do
		table.insert(piles, { marker = pileMarkers[#piles + 1].id, kind = kinds[rng:NextInteger(1, #kinds)] })
		topped += 1
	end
	plan.value = OfficeLootUtils.valueOf(plan).full
	return plan
end

--[=[
	How many salvage items a plan offers: on the open floor, hidden under piles and in desks or lockers (the review's
	"salvage found N of M"). The greed target is placed through one of those lists, so it is counted once.
]=]
function OfficeSpawnUtils.salvageCount(plan: OfficeTypes.SpawnPlan): number
	local count = 0
	local function add(kind: string?)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if def ~= nil and def.category == "salvage" then
			count += 1
		end
	end
	for _, item in plan.items do
		add(item.kind)
	end
	for _, pile in plan.piles do
		add(pile.hides)
	end
	for _, search in plan.searchables do
		add(search.kind)
	end
	return count
end

return OfficeSpawnUtils
