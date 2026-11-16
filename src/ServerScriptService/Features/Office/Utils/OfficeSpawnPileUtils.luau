--!strict
--[=[
	OfficeSpawnPileUtils: where one shift's piles stand (step 1 of OfficeSpawnUtils.roll). `pileOrder` picks the dirty
	rooms (apart from each other where the layout allows, by `neighbours`) and their piles' markers, then lists the free
	markers in top-up order; no two piles' art boxes overlap (`crowds`, PILE_REACH). `shuffled` is the shared
	Fisher-Yates shuffle the roll also uses. Split out of OfficeSpawnUtils, which calls it. Deterministic for a given
	Random (`rng` is consumed in the same order as before the split). Pure.

	@class OfficeSpawnPileUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

type Marker = OfficeTypes.Marker

local OfficeSpawnPileUtils = {}

-- The biggest pile art footprint (artSize X and Z over every kind): piles spawn unrotated, so two piles' art boxes
-- overlap unless their markers are this far apart along X or along Z, whatever kinds they roll.
local PILE_REACH = (function(): Vector2
	local x, z = 0, 0
	for _, style in VacuumConstants.PILE_KINDS do
		x, z = math.max(x, style.artSize.X), math.max(z, style.artSize.Z)
	end
	return Vector2.new(x, z)
end)()

-- Whether a pile on `marker` would show its art through a pile on any of `taken`.
local function crowds(marker: Marker, taken: { Marker }): boolean
	for _, other in taken do
		if math.abs(marker.x - other.x) < PILE_REACH.X and math.abs(marker.z - other.z) < PILE_REACH.Y then
			return true
		end
	end
	return false
end

local function shuffled<T>(list: { T }, rng: Random): { T }
	local copy = table.clone(list)
	for index = #copy, 2, -1 do
		local swap = rng:NextInteger(1, index)
		copy[index], copy[swap] = copy[swap], copy[index]
	end
	return copy
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
function OfficeSpawnPileUtils.pileOrder(
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
	-- How many piles a room can hold with no two piles' art overlapping (its markers taken greedily).
	local function fits(room: string): number
		local held: { Marker } = {}
		for _, marker in byRoom[room] do
			if not crowds(marker, held) then
				table.insert(held, marker)
			end
		end
		return #held
	end
	local wanted = rng:NextInteger(options.dirtyRooms.min, options.dirtyRooms.max)
	local dirty: { string } = {}
	local chosen: { [string]: boolean } = {}
	for pass = 1, 3 do
		for _, room in order do
			if #dirty >= wanted then
				break
			end
			if not chosen[room] then
				local roomy = fits(room) >= options.pilesPerRoom.min
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
	-- A marker whose pile art would overlap one already taken is never used (dirty rooms are the ones roomy enough to
	-- hold their piles apart). A pile its room still cannot fit moves to another dirty room's free marker that fits,
	-- never past PILES_PER_ROOM.max there, so the dust stays in the dirty rooms and the shift keeps its Gloom. The
	-- spares after them (a top-up's: the dirty rooms' leftovers first, then the clean rooms') never crowd either.
	local used: { Marker } = {}
	local spare: { Marker } = {}
	local held: { [string]: number } = {}
	local rolled = 0
	for _, room in dirty do
		local markers = shuffled(byRoom[room], rng)
		local count = math.min(rng:NextInteger(options.pilesPerRoom.min, options.pilesPerRoom.max), #markers)
		rolled += count
		held[room] = 0
		for _, marker in markers do
			if held[room] < count and not crowds(marker, used) then
				table.insert(used, marker)
				held[room] += 1
			else
				table.insert(spare, marker)
			end
		end
	end
	local rest: { Marker } = {}
	for _, marker in spare do
		if #used < rolled and held[marker.room] < options.pilesPerRoom.max and not crowds(marker, used) then
			table.insert(used, marker)
			held[marker.room] += 1
		else
			table.insert(rest, marker)
		end
	end
	local count = #used
	for _, room in order do
		if not chosen[room] then
			for _, marker in byRoom[room] do
				table.insert(rest, marker)
			end
		end
	end
	for _, marker in rest do
		if not crowds(marker, used) then
			table.insert(used, marker)
		end
	end
	return used, count
end

OfficeSpawnPileUtils.PILE_REACH = PILE_REACH
OfficeSpawnPileUtils.crowds = crowds
OfficeSpawnPileUtils.shuffled = shuffled
OfficeSpawnPileUtils.neighbours = neighbours

return OfficeSpawnPileUtils
