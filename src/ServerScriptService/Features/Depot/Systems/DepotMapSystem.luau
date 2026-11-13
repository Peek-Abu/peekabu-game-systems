--!strict
--[=[
	DepotMapSystem: the truck map pick on the server (the School map plan), split out of DepotServiceServer.

	- A truck's host (crew hosting's, HostServiceServer:hostOf) sends DepotEvents.PickMap (from the places menu); a pick
	  from anyone else, of no map, or of a place the host has not unlocked (DepotPlaceSystem.owns) is dropped. Picks live in a DepotMapTracker and are published as the
	  DepotConstants.MAP_WORLD_ENTRY world entry, so every client aboard sees the host's pick.
	- DepotServiceServer reads a truck's pick into the depart data (`mapOfPad`), forgets it when the party departs
	  (`departed`), and each tick hands over the trucks so a truck with no host left (it emptied) starts over on the
	  office (`refresh`). A truck nobody picked for plays the office.

	Spec-exempt shell (ByteNet, Queue and Host wiring, the world store); the decisions are the specced DepotMapRules
	and DepotMapTracker.

	@class DepotMapSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotEvents = require(ReplicatedStorage.Shared.Features.Depot.Net.DepotEvents)
local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotMapTracker = require(ServerScriptService.Features.Depot.State.DepotMapTracker)
local DepotPlaceSystem = require(ServerScriptService.Features.Depot.Systems.DepotPlaceSystem)
local HostServiceServer = require(ServerScriptService.Features.Host.HostServiceServer)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)

-- Each truck's map pick (by Queue pad id).
local maps = DepotMapTracker.new()
-- Accepted picks since start, for the Debugger.
local accepted = 0

local function publish()
	StateSyncWorldStore.set(DepotConstants.MAP_WORLD_ENTRY, maps:snapshot())
end

-- A host's map pick for the truck they are aboard. Dropped unless the id is a map and the sender hosts that truck.
local onPickMap = RequestHandler.wrap({
	name = "DepotPickMap",
	rateLimit = DepotConstants.MAP_REQUEST_RATE,
	handler = function(data: unknown, player: Player)
		if not DepotMapRules.isMap(data) then
			return
		end
		local pad = QueueServiceServer:padOf(player)
		local padId = if pad ~= nil then QueueServiceServer.pads:padIdOf(pad) else nil
		if pad == nil or padId == nil then
			return
		end
		if not DepotMapRules.canPick(player.UserId, HostServiceServer:hostOf(pad)) then
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

local DepotMapSystem = {}

-- Listens for picks and publishes the (empty) entry. Returns the stop, which forgets every pick and clears the entry.
function DepotMapSystem.start(): () -> ()
	local picking = DepotEvents.packets.PickMap.listen(function(data: string, player: Player?)
		if player then
			onPickMap(data, player)
		end
	end)
	publish()
	return function()
		picking()
		maps:reset()
		accepted = 0
		StateSyncWorldStore.clear(DepotConstants.MAP_WORLD_ENTRY)
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

-- Truck `pad`'s party departed (its pick already rode the depart data): the truck starts over.
function DepotMapSystem.departed(pad: BasePart)
	local padId = QueueServiceServer.pads:padIdOf(pad)
	if padId ~= nil and maps:clear(padId) then
		publish()
	end
end

-- Forgets the picks of the trucks among `pads` with no host left (emptied), or whose host (passed to someone new)
-- does not own the picked place: that truck starts over on the office.
function DepotMapSystem.refresh(pads: { BasePart })
	local live: { [string]: boolean } = {}
	for _, pad in pads do
		local padId = QueueServiceServer.pads:padIdOf(pad)
		local host = HostServiceServer:hostOf(pad)
		if padId ~= nil and host ~= nil and DepotPlaceSystem.owns(host, maps:mapOf(padId)) then
			live[padId] = true
		end
	end
	if maps:retain(live) then
		publish()
	end
end

-- Accepted picks since start.
function DepotMapSystem.picks(): number
	return accepted
end

return DepotMapSystem
