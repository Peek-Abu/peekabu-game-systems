--!strict
--[=[
	OfficeSpawnUtils: rolls one shift's spawns onto the layout's markers (Cleanup Crew spec §4 "Spawn
	guarantees", §1 "randomised spawns"; the loot loop, docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md
	§3.5). Deterministic for a given Random: the catalog is walked in sorted order and `rng` is consumed in a fixed
	sequence:

	1. piles, clustered: `options.dirtyRooms` dirty rooms with clean rooms between them where the layout allows, each
	   holding `options.pilesPerRoom` piles on its own shuffled pile markers, each a random pile kind (pileOrder);
	2. desks and lockers: each holds a desk-weighted valuable with SEARCH_FILL_CHANCE, else nothing; after
	   DESK_VALUABLES_MAX valuables, nothing;
	3. the greed target (fish tank, filing cabinet or golden stapler), always in a deep room: a hidden one
	   (the stapler) in a deep desk or locker (else under a deep pile), the others on a deep item marker;
	4. the valuables budget, a count in `options.valuables` that the greed target and desk valuables count toward;
	5. buried loot: one BURY_CHANCE draw per pile (OfficeLootUtils.buried), each hit burying a buriable valuable,
	   capped so MIN_OPEN of the budget is left for the open;
	6. the rest of the budget in the open (on item markers, or the furniture tops their kind belongs on);
	7. the top-up: plain piles on free pile markers (the dirty rooms' leftovers first), at most TOP_UP_MAX, while the site's Gloom is too thin for the
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

local function shuffled<T>(list: { T }, rng: Random): { T }
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

-- Which rooms are next to which: they share a doorway, or one corridor piece joins them and their two doors are within
-- NEIGHBOUR_DOOR_STUDS of each other (a corridor is not a room, but far along a long one is not "next door").
type Link = { room: string, x: number, z: number }
local function neighbours(layout: OfficeTypes.Layout): { [string]: { [string]: boolean } }
	local halls: { [string]: boolean } = {}
	for _, room in layout.rooms do
		if room.zone == "hallway" then
			halls[room.id] = true
		end
	end
	local direct: { [string]: { Link } } = {}
	local function link(a: string, b: string, door: OfficeTypes.Door)
		local list = direct[a]
		if list == nil then
			list = {}
			direct[a] = list
		end
		table.insert(list, { room = b, x = door.x, z = door.z })
	end
	for _, door in layout.doors do
		link(door.a, door.b, door)
		link(door.b, door.a, door)
	end
	local result: { [string]: { [string]: boolean } } = {}
	local function mark(a: string, b: string)
		if a == b then
			return
		end
		local set = result[a]
		if set == nil then
			set = {}
			result[a] = set
		end
		set[b] = true
	end
	for a, list in direct do
		for _, via in list do
			local through = direct[via.room]
			if halls[via.room] and through ~= nil then
				for _, far in through do
					local apart = math.sqrt((far.x - via.x) ^ 2 + (far.z - via.z) ^ 2)
					if apart <= OfficeConstants.NEIGHBOUR_DOOR_STUDS then
						mark(a, far.room)
					end
				end
			else
				mark(a, via.room)
			end
		end
	end
	return result
end

--[=[
	Step 1's markers: the piles' markers in pile order, then the free ones in top-up order, and how many of them
	the piles take. DIRTY_ROOMS-many rooms are dirty (`options.dirtyRooms`), chosen in a shuffled order: first rooms with
	at least `options.pilesPerRoom.min` pile markers and no dirty neighbour (neighbours), then any with that many, then
	any. Each dirty room holds `options.pilesPerRoom` piles (at most its markers) on its own shuffled markers. The free
	markers list the dirty rooms' leftovers first, then the clean rooms', room by room, so a top-up keeps the dust in
	clusters.
]=]
local function pileOrder(
	layout: OfficeTypes.Layout,
	options: OfficeTypes.RollOptions,
	rng: Random
): ({ Marker }, number)
	local byRoom: { [string]: { Marker } } = {}
	local rooms: { string } = {}
	for _, marker in OfficeLayoutUtils.markersOf(layout, "pile") do
		local list = byRoom[marker.room]
		if list == nil then
			list = {}
			byRoom[marker.room] = list
			table.insert(rooms, marker.room)
		end
		table.insert(list, marker)
	end
	local order = shuffled(rooms, rng)
	local near = neighbours(layout)
	local wanted = rng:NextInteger(options.dirtyRooms.min, options.dirtyRooms.max)
	local dirty: { string } = {}
	local chosen: { [string]: boolean } = {}
	for pass = 1, 3 do
		for _, room in order do
			if #dirty >= wanted then
				break
			end
			if not chosen[room] then
				local roomy = #byRoom[room] >= options.pilesPerRoom.min
				local apart = true
				local around = near[room]
				if around ~= nil then
					for other in chosen do
						if around[other] then
							apart = false
						end
					end
				end
				local take = if pass == 1 then roomy and apart elseif pass == 2 then roomy else true
				if take then
					chosen[room] = true
					table.insert(dirty, room)
				end
			end
		end
	end
	local used: { Marker } = {}
	local spare: { Marker } = {}
	for _, room in dirty do
		local markers = shuffled(byRoom[room], rng)
		local count = math.min(rng:NextInteger(options.pilesPerRoom.min, options.pilesPerRoom.max), #markers)
		for index, marker in markers do
			table.insert(if index <= count then used else spare, marker)
		end
	end
	for _, room in order do
		if not chosen[room] then
			for _, marker in byRoom[room] do
				table.insert(spare, marker)
			end
		end
	end
	local count = #used
	for _, marker in spare do
		table.insert(used, marker)
	end
	return used, count
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

	-- 1. Piles, clustered: the dirty rooms, then each one's piles on its own shuffled pile markers. `pileMarkers` lists
	-- the markers the piles stand on (in pile order), then the free ones in top-up order (step 7).
	local pileMarkers, pileCount = pileOrder(layout, options, rng)
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
	The spots the first roll left free for the overtime batch: item markers and furniture tops that no item of `plan`
	stands on, in layout order. (Piles, desks and lockers are never overtime spots.)
]=]
function OfficeSpawnUtils.freeSpots(layout: OfficeTypes.Layout, plan: OfficeTypes.SpawnPlan): { Marker }
	local used: { [string]: boolean } = {}
	for _, item in plan.items do
		used[item.marker] = true
	end
	local list: { Marker } = {}
	for _, marker in layout.markers do
		if not used[marker.id] and (marker.kind == "item" or OfficeLayoutUtils.surfaceTopY(marker.kind) ~= nil) then
			table.insert(list, marker)
		end
	end
	return list
end

--[=[
	Rolls the overtime batch onto the spots the first `plan` left free (`freeSpots`): OfficeSpawnRules.overtimeBatchSize
	valuables, each an open salvage kind (same weights and surface rules as the shift's open valuables), appraised for
	its spot's depth. Deterministic for a given `rng`. Empty when no spot is free.
]=]
function OfficeSpawnUtils.rollOvertime(
	layout: OfficeTypes.Layout,
	plan: OfficeTypes.SpawnPlan,
	rng: Random
): { OfficeTypes.ItemPlan }
	local free = OfficeSpawnUtils.freeSpots(layout, plan)
	local count = OfficeSpawnRules.overtimeBatchSize(OfficeSpawnUtils.salvageCount(plan), #free)
	local batch: { OfficeTypes.ItemPlan } = {}
	if count == 0 then
		return batch
	end
	local depths = OfficeLayoutUtils.depths(layout)
	local pool = shuffled(free, rng)
	local function takeSurface(itemId: string): Marker?
		for _, wanted in OfficeSpawnRules.surfaceKindsFor(itemId) do
			for index, marker in pool do
				if marker.kind == wanted then
					return table.remove(pool, index)
				end
			end
		end
		return nil
	end
	local function hasSurface(itemId: string): boolean
		for _, wanted in OfficeSpawnRules.surfaceKindsFor(itemId) do
			for _, marker in pool do
				if marker.kind == wanted then
					return true
				end
			end
		end
		return false
	end
	local function takeFloor(): Marker?
		for index, marker in pool do
			if marker.kind == "item" then
				return table.remove(pool, index)
			end
		end
		return nil
	end
	for _ = 1, count do
		local kind = pickWeighted(function(def)
			return if OfficeSpawnRules.requiresSurface(def.id) and not hasSurface(def.id) then 0 else salvageWeight(def)
		end, rng)
		local def = if kind ~= nil then CargoRegistry.get(kind) else nil
		if kind == nil or def == nil then
			break
		end
		local spot = if #surfaceFor(def) > 0 then takeSurface(kind) else nil
		if spot == nil then
			spot = takeFloor()
		end
		if spot == nil then
			break
		end
		local appraisal = if def.grimy then CargoAppraisalFormulas.roll(def, depths[spot.room] or 0, rng) else nil
		table.insert(batch, { marker = spot.id, kind = kind, appraisal = appraisal })
	end
	return batch
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
