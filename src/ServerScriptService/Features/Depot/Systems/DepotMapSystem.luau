--!strict
--[=[
	DepotMapSystem: the truck's picks on the server, split out of DepotServiceServer: the map (the School map plan) and
	the run mode (Night Shift or Quick shift, owner concept B 11-18).

	- A truck's host (crew hosting's, HostServiceServer:hostOf) sends DepotEvents.PickMap (from the places menu); a pick
	  from anyone else, of no map, or of a place the host has not unlocked (DepotPlaceSystem.owns) is dropped. Picks live in a DepotMapTracker and are published as the
	  DepotConstants.MAP_WORLD_ENTRY world entry, so every client aboard sees the host's pick.
	- The host's DepotEvents.PickMode (the same panel) is checked the same way (a mode, from the host) and lives in a
	  DepotModeTracker, published as DepotConstants.MODE_WORLD_ENTRY. A truck nobody picked for plays the default mode
	  (Night Shift).
	- DepotServiceServer reads a truck's picks into the depart data (`mapOfPad`, `modeOfPad`), forgets them when the
	  party departs (`departed`), and each tick hands over the trucks so a truck with no host left (it emptied) starts
	  over on the office and the default mode (`refresh`). A truck nobody picked for plays the office.

	Spec-exempt shell (ByteNet, Queue and Host wiring, the world store); the decisions are the specced DepotMapRules,
	DepotMapTracker, DepotModeRules and DepotModeTracker.

	@class DepotMapSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotEvents = require(ReplicatedStorage.Shared.Features.Depot.Net.DepotEvents)
local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local DepotModeRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotModeRules)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotMapTracker = require(ServerScriptService.Features.Depot.State.DepotMapTracker)
local DepotModeTracker = require(ServerScriptService.Features.Depot.State.DepotModeTracker)
local DepotPlaceSystem = require(ServerScriptService.Features.Depot.Systems.DepotPlaceSystem)
local HostServiceServer = require(ServerScriptService.Features.Host.HostServiceServer)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)

-- Each truck's map pick and run mode pick (by Queue pad id).
local maps = DepotMapTracker.new()
local modes = DepotModeTracker.new()
-- Accepted picks since start (maps and modes), for the Debugger.
local accepted = 0

local function publish()
	StateSyncWorldStore.set(DepotConstants.MAP_WORLD_ENTRY, maps:snapshot())
end

local function publishModes()
	StateSyncWorldStore.set(DepotConstants.MODE_WORLD_ENTRY, modes:snapshot())
end

-- The pad id of the truck `player` hosts, or nil when they are aboard none or do not host it.
local function hostedPadId(player: Player): string?
	local pad = QueueServiceServer:padOf(player)
	local padId = if pad ~= nil then QueueServiceServer.pads:padIdOf(pad) else nil
	if pad == nil or padId == nil then
		return nil
	end
	if not DepotMapRules.canPick(player.UserId, HostServiceServer:hostOf(pad)) then
		return nil
	end
	return padId
end

-- A host's map pick for the truck they are aboard. Dropped unless the id is a map and the sender hosts that truck.
local onPickMap = RequestHandler.wrap({
	name = "DepotPickMap",
	rateLimit = DepotConstants.MAP_REQUEST_RATE,
	handler = function(data: unknown, player: Player)
		if not DepotMapRules.isMap(data) then
			return
		end
		local padId = hostedPadId(player)
		if padId == nil then
			return
		end
		-- A locked place (the School before the host bought it) is never picked.
		local map: ShiftTypes.MapId = DepotMapRules.parse(data)
		if not DepotPlaceSystem.owns(player.UserId, map) then
			return
		end
		if maps:pick(padId, map) then
			accepted += 1
			publish()
		end
	end,
})

-- A host's run mode pick for the truck they are aboard. Dropped unless it is a mode and the sender hosts that truck.
local onPickMode = RequestHandler.wrap({
	name = "DepotPickMode",
	rateLimit = DepotConstants.MODE_REQUEST_RATE,
	handler = function(data: unknown, player: Player)
		if not DepotModeRules.isMode(data) then
			return
		end
		local padId = hostedPadId(player)
		if padId == nil then
			return
		end
		if modes:pick(padId, DepotModeRules.parse(data)) then
			accepted += 1
			publishModes()
		end
	end,
})

local DepotMapSystem = {}

-- Listens for picks and publishes the (empty) entries. Returns the stop, which forgets every pick and clears them.
function DepotMapSystem.start(): () -> ()
	local picking = DepotEvents.packets.PickMap.listen(function(data: string, player: Player?)
		if player then
			onPickMap(data, player)
		end
	end)
	local pickingMode = DepotEvents.packets.PickMode.listen(function(data: string, player: Player?)
		if player then
			onPickMode(data, player)
		end
	end)
	publish()
	publishModes()
	return function()
		picking()
		pickingMode()
		maps:reset()
		modes:reset()
		accepted = 0
		StateSyncWorldStore.clear(DepotConstants.MAP_WORLD_ENTRY)
		StateSyncWorldStore.clear(DepotConstants.MODE_WORLD_ENTRY)
	end
end

-- The map truck `pad`'s host picked (the office when none, or when its host no longer hosts or owns the pick).
function DepotMapSystem.mapOfPad(pad: BasePart): ShiftTypes.MapId
	local padId = QueueServiceServer.pads:padIdOf(pad)
	local map: ShiftTypes.MapId = if padId ~= nil then maps:mapOf(padId) else DepotMapRules.parse(nil)
	local host = HostServiceServer:hostOf(pad)
	if host == nil or not DepotPlaceSystem.owns(host, map) then
		return DepotMapRules.parse(nil)
	end
	return map
end

-- The run mode truck `pad`'s host picked (the default when none, or when nobody hosts it).
function DepotMapSystem.modeOfPad(pad: BasePart): ShiftTypes.RunMode
	local padId = QueueServiceServer.pads:padIdOf(pad)
	if padId == nil or HostServiceServer:hostOf(pad) == nil then
		return DepotModeRules.parse(nil)
	end
	return modes:modeOf(padId)
end

-- Truck `pad`'s party departed (its picks already rode the depart data): the truck starts over.
function DepotMapSystem.departed(pad: BasePart)
	local padId = QueueServiceServer.pads:padIdOf(pad)
	if padId == nil then
		return
	end
	if maps:clear(padId) then
		publish()
	end
	if modes:clear(padId) then
		publishModes()
	end
end

-- Forgets the picks of the trucks among `pads` with no host left (emptied), and the map picks of those whose host
-- (passed to someone new) does not own the picked place: that truck starts over on the office (and, emptied, on the
-- default mode).
function DepotMapSystem.refresh(pads: { BasePart })
	local live: { [string]: boolean } = {}
	local hosted: { [string]: boolean } = {}
	for _, pad in pads do
		local padId = QueueServiceServer.pads:padIdOf(pad)
		local host = HostServiceServer:hostOf(pad)
		if padId ~= nil and host ~= nil then
			hosted[padId] = true
			if DepotPlaceSystem.owns(host, maps:mapOf(padId)) then
				live[padId] = true
			end
		end
	end
	if maps:retain(live) then
		publish()
	end
	if modes:retain(hosted) then
		publishModes()
	end
end

-- Accepted picks since start.
function DepotMapSystem.picks(): number
	return accepted
end

return DepotMapSystem
