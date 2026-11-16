--!strict
--[=[
	OfficeLayoutGenerationUtils: a fresh workplace from a seed. The corridor network (OfficeCorridorUtils) is the
	skeleton; the loading bay hangs off the dock junction, the reception off the lobby junction, and hand-authored
	kit rooms (OfficeKitRegistry, placed by OfficeKitUtils; the lining is OfficeRoomLiningUtils) line the corridor segments on both sides, spread round-robin (each segment takes one room per round); a kit's glass
	pane is clipped to the corridor it faces, so no window looks out of the building. Dead-end
	corridors that serve no room are pruned (a closet stands in each dead end left; OfficeJunctionUtils), a stairwell and an elevator
	facade go on free junction walls (OfficeFacadeUtils), and Mr. Harlow's patrol route and rest point are derived
	from the result.

	`generate` builds up to GENERATE_ATTEMPTS layouts (seed * 31 + attempt) and returns the first that is valid,
	has the markers the spawn roll needs, the hiding places and the walking distance the map promises, and the room
	mix (one server room and one reception, at least one breakout, KIT_ROOMS rooms in all). Pure.

	@class OfficeLayoutGenerationUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Features.Office
local OfficeConstants = require(Server.Data.OfficeConstants)
local OfficeCorridorUtils = require(script.Parent.OfficeCorridorUtils)
local OfficeFacadeUtils = require(script.Parent.OfficeFacadeUtils)
local OfficeGroundsUtils = require(script.Parent.OfficeGroundsUtils)
local OfficeHallDressingUtils = require(script.Parent.OfficeHallDressingUtils)
local OfficeKitRegistry = require(Server.Data.OfficeKitRegistry)
local OfficeJunctionUtils = require(script.Parent.OfficeJunctionUtils)
local OfficeKitUtils = require(script.Parent.OfficeKitUtils)
local OfficeLayoutRules = require(Server.Rules.OfficeLayoutRules)
local OfficeLayoutUtils = require(script.Parent.OfficeLayoutUtils)
local OfficeLoadingBayUtils = require(script.Parent.OfficeLoadingBayUtils)
local OfficeRoomLiningUtils = require(script.Parent.OfficeRoomLiningUtils)
local OfficeTypes = require(Server.Data.OfficeTypes)

type Layout = OfficeTypes.Layout
type Room = OfficeTypes.Room
type Network = OfficeCorridorUtils.Network
type Build = OfficeRoomLiningUtils.Build

local ENTRANCE_WIDTH = 12

local OfficeLayoutGenerationUtils = {}

local overlaps = OfficeRoomLiningUtils.overlaps
local addMarkers = OfficeRoomLiningUtils.addMarkers
local commit = OfficeRoomLiningUtils.commit

local function center(room: Room): (number, number)
	return (room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2
end

-- A 6-wide facade of `kind` (the stairwell, the elevator) on a live junction's free wall (OfficeFacadeUtils), drawn
-- from the seed.
local function addFacade(
	build: Build,
	network: Network,
	alive: { [string]: boolean },
	kind: "stairwell" | "elevator"
): boolean
	local junctions: { Room } = {}
	for _, junction in network.rooms do
		if alive[junction.id] and network.junctions[junction.id] ~= nil then
			table.insert(junctions, junction)
		end
	end
	local candidates = OfficeFacadeUtils.candidates(build.layout, junctions, build.facades, kind)
	if #candidates == 0 then
		return false
	end
	table.insert(build.facades, candidates[build.rng:NextInteger(1, #candidates)])
	return true
end

-- Harlow's loop: a DFS from the dock junction over doors (never into the bay) that appends each room's patrol
-- marker on entry and the parent's again on backtrack.
local function buildRoute(layout: Layout, network: Network): { string }
	local patrols: { [string]: string } = {}
	for _, marker in layout.markers do
		if marker.kind == "patrol" then
			patrols[marker.room] = marker.id
		end
	end
	local adjacent: { [string]: { string } } = {}
	for _, door in layout.doors do
		if door.a ~= "bay" and door.b ~= "bay" then
			adjacent[door.a] = adjacent[door.a] or {}
			adjacent[door.b] = adjacent[door.b] or {}
			table.insert(adjacent[door.a], door.b)
			table.insert(adjacent[door.b], door.a)
		end
	end
	local route: { string } = {}
	local seen: { [string]: boolean } = {}
	local function walk(id: string)
		seen[id] = true
		local own = patrols[id]
		local function visit()
			if own ~= nil and route[#route] ~= own then
				table.insert(route, own)
			end
		end
		visit()
		local others: { string } = adjacent[id] or {}
		for _, other in others do
			if not seen[other] then
				walk(other)
				visit()
			end
		end
	end
	walk(network.dock.id)
	-- Into the loading bay and back once, from the dock junction's first visit.
	local entry = patrols[network.dock.id]
	local at = if entry ~= nil then table.find(route, entry) else nil
	if entry ~= nil and at ~= nil then
		table.insert(route, at + 1, "bay.patrol.1")
		table.insert(route, at + 2, entry)
	end
	return route
end

-- One attempt at a map; nil and the reason when this roll cannot make one.
local function construct(base: Layout, rng: Random): (Layout?, string?)
	local network = OfficeCorridorUtils.network(rng)
	if #network.segments < #network.rooms - #network.segments then
		return nil, "the corridor network has no loop"
	end
	local layout: Layout = {
		artKit = OfficeConstants.GENERATED_ART_KIT,
		startRoom = "bay",
		rooms = {},
		doors = {},
		markers = {},
		truck = table.clone(base.truck),
		route = {},
		rest = "",
	}
	local box: Room =
		{ id = "box", name = "box", minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, room in network.rooms do
		box.minX, box.maxX = math.min(box.minX, room.minX), math.max(box.maxX, room.maxX)
		box.minZ, box.maxZ = math.min(box.minZ, room.minZ), math.max(box.maxZ, room.maxZ)
	end
	local state: Build = {
		rng = rng,
		layout = layout,
		solid = table.clone(network.rooms),
		box = box,
		counts = {},
		facades = {},
		panes = {},
		placed = 0,
		needServer = true,
		needBreakout = true,
		pending = nil,
	}

	-- The loading bay, south of the dock junction; the truck and the crew's arrival points are outside, in the yard.
	local bay, bayDoor = OfficeLoadingBayUtils.bay(3, network.dock)
	table.insert(state.solid, bay)
	layout.grounds = OfficeGroundsUtils.grounds()
	layout.truck = OfficeGroundsUtils.truck()
	addMarkers(state, OfficeGroundsUtils.arrivalMarkers(layout.truck))
	addMarkers(state, OfficeGroundsUtils.bayShelves(bay))
	local patrol = OfficeLoadingBayUtils.patrolPoint(bay, 3)
	table.insert(
		layout.markers,
		{ id = "bay.patrol.1", room = "bay", kind = "patrol", x = patrol.X, z = patrol.Y, rotation = 0 }
	)

	-- The reception faces the lobby junction's -X wall, its door on the junction's centre line.
	local lobby = network.lobby
	local _, lobbyZ = center(lobby)
	local kit = OfficeKitRegistry.ofType("reception")[1]
	local reception = OfficeKitUtils.place(kit, "reception1", lobby.minX, lobbyZ - kit.door.offset, "maxX", false)
	for _, other in state.solid do
		if overlaps(reception.room, other) then
			return nil, `the reception overlaps {other.id}`
		end
	end
	state.counts.reception = 1
	commit(state, reception.room, {
		a = "reception1",
		b = lobby.id,
		x = reception.doorX,
		z = reception.doorZ,
		width = reception.doorWidth,
		kind = reception.doorKind,
	}, reception.markers)
	local _, receptionZ = center(reception.room)
	layout.entrances = {
		OfficeGroundsUtils.dockEntrance(bay),
		OfficeGroundsUtils.lobbyEntrance(reception.room, receptionZ, ENTRANCE_WIDTH),
	}

	-- The deck: a server room and a breakout lounge, then weighted draws up to the target (reception counts).
	local target = rng:NextInteger(OfficeConstants.KIT_ROOMS.min, OfficeConstants.KIT_ROOMS.max)
	OfficeRoomLiningUtils.lineSegments(state, network, target - 1)

	-- Prune dead ends that serve no room; closets and patrol points on what is left.
	local served: { [string]: boolean } = {}
	for _, door in layout.doors do
		served[door.b] = true
	end
	local alive = OfficeJunctionUtils.pruneDeadEnds(network, served)
	local rooms: { Room } = {}
	for _, room in network.rooms do
		if alive[room.id] then
			table.insert(rooms, room)
		end
	end
	table.insert(rooms, bay)
	for _, room in layout.rooms do
		table.insert(rooms, room)
	end
	layout.rooms = rooms
	local doors: { OfficeTypes.Door } = {}
	for _, door in network.doors do
		if alive[door.a] and alive[door.b] then
			table.insert(doors, door)
		end
	end
	table.insert(doors, bayDoor)
	for _, door in layout.doors do
		table.insert(doors, door)
	end
	layout.doors = doors
	-- Every room's depth: its walk from the bay in DEPTH_STUDS steps (corridor pieces add doors, not distance).
	local walked = OfficeLayoutUtils.walkDistances(layout)
	for _, room in layout.rooms do
		local distance = walked[room.id]
		if distance ~= nil then
			room.depth = math.floor(distance / OfficeConstants.DEPTH_STUDS)
		end
	end
	addMarkers(state, OfficeJunctionUtils.markers(network, alive))

	if not addFacade(state, network, alive, "stairwell") then
		return nil, "no junction wall has room for the stairwell"
	end
	if not addFacade(state, network, alive, "elevator") then
		return nil, "no junction wall has room for the elevator"
	end

	layout.facades, layout.panes = state.facades, state.panes
	for _, room in layout.rooms do
		if room.zone == "hallway" then
			addMarkers(state, OfficeHallDressingUtils.dress(room, layout, rng, network.junctions[room.id] ~= nil))
		end
	end
	layout.route = buildRoute(layout, network)
	for _, room in layout.rooms do
		if room.roomType == "breakout" then
			layout.rest = `{room.id}.rest.1`
			break
		end
	end
	return layout, nil
end

-- Why `layout` is not good enough, or nil.
local function problem(layout: Layout): string?
	local ok, errors = OfficeLayoutRules.validate(layout)
	if not ok then
		return `invalid: {table.concat(errors, "; ")}`
	end
	for _, check in
		{
			OfficeLayoutRules.checkCapacity,
			OfficeLayoutRules.checkRoute,
			OfficeLayoutRules.checkHideSpots,
		}
	do
		local passed, reason = check(layout)
		if not passed then
			return reason
		end
	end
	local walked, walkReason =
		OfficeLayoutRules.checkWalk(layout, OfficeConstants.WALK_SPEED * OfficeConstants.MAX_WALK_SECONDS)
	if not walked then
		return walkReason
	end
	local kits, servers, receptions, breakouts = 0, 0, 0, 0
	for _, room in layout.rooms do
		if room.kit ~= nil then
			kits += 1
			servers += if room.roomType == "server" then 1 else 0
			receptions += if room.roomType == "reception" then 1 else 0
			breakouts += if room.roomType == "breakout" then 1 else 0
		end
	end
	if kits < OfficeConstants.KIT_ROOMS.min or kits > OfficeConstants.KIT_ROOMS.max then
		return `{kits} kit rooms (wanted {OfficeConstants.KIT_ROOMS.min}-{OfficeConstants.KIT_ROOMS.max})`
	end
	if servers ~= 1 or receptions ~= 1 or breakouts < 1 then
		return `{servers} server rooms, {receptions} receptions, {breakouts} breakouts`
	end
	return nil
end

--[=[
	A fresh map for `seed`: the first of GENERATE_ATTEMPTS builds (Random seed * 31 + attempt) that passes
	`problem`. Errors, listing why each attempt failed, when none does.
]=]
function OfficeLayoutGenerationUtils.generate(base: Layout, seed: number): Layout
	local reasons: { string } = {}
	for attempt = 0, OfficeConstants.GENERATE_ATTEMPTS - 1 do
		local layout, reason = construct(base, Random.new(seed * 31 + attempt))
		if layout ~= nil then
			reason = problem(layout)
			if reason == nil then
				return layout
			end
		end
		table.insert(reasons, `attempt {attempt}: {reason or "?"}`)
	end
	error(`no office layout for seed {seed}: {table.concat(reasons, " | ")}`)
end

return OfficeLayoutGenerationUtils
