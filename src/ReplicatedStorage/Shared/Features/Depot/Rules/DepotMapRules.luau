--!strict
--[=[
	DepotMapRules: the truck's map pick (the School map plan). Only a truck's host picks its map (`canPick`; the host is
	crew hosting's, HostServiceServer:hostOf); the maps are OFFICE and SCHOOL. `parse` reads a
	map off anything untrusted (the depart payload riding the teleport, a client's pick): only an exact map id counts,
	anything else is the office. `decode` reads the published picks (the DepotConstants.MAP_WORLD_ENTRY world entry) on
	a client, dropping bad entries; `mapOf` is a truck's pick, the office when it has none. `contractsOf` is a map's jobs
	(the Office's DepotConstants.CONTRACTS, the School's SCHOOL_CONTRACTS), `mapOfClient` the map a finished run's client
	was on (the hub's review card carries only the client), and `siteOf` its words during a run (the route slip, the
	HUD, the review): every Office/School word is chosen here, by the run's map.

	@class DepotMapRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)

type MapId = ShiftTypes.MapId

-- Each truck's pick, by Queue pad id.
export type Picks = { [string]: MapId }

-- The map `value` names, or nil when it names none.
local function mapFrom(value: unknown): MapId?
	if value == "office" then
		return "office"
	elseif value == "school" then
		return "school"
	end
	return nil
end

export type DepotMapRules = {
	isMap: (value: unknown) -> boolean,
	parse: (value: unknown) -> MapId,
	canPick: (userId: number, host: number?) -> boolean,
	decode: (value: WorldTypes.WorldValue?) -> Picks,
	mapOf: (picks: Picks, padId: string?) -> MapId,
	contractsOf: (map: MapId) -> { DepotTypes.Contract },
	mapOfClient: (client: string) -> MapId,
	siteOf: (map: MapId) -> DepotTypes.MapSite,
}

local DepotMapRules: DepotMapRules = {
	isMap = function(value)
		return mapFrom(value) ~= nil
	end,

	-- The map `value` names; anything that is not exactly a map id is the office.
	parse = function(value)
		local map: MapId? = mapFrom(value)
		return if map ~= nil then map else "office"
	end,

	-- Whether `userId` may pick the map of a truck hosted by `host` (nil: nobody hosts it).
	canPick = function(userId, host)
		return host ~= nil and userId == host
	end,

	-- The picks in the world entry; a bad entry is dropped, a missing or malformed entry is no picks.
	decode = function(value)
		local picks: Picks = {}
		if type(value) ~= "table" then
			return picks
		end
		for key, item in value do
			local map: MapId? = mapFrom(item)
			if map ~= nil and type(key) == "string" then
				picks[key] = map
			end
		end
		return picks
	end,

	-- The map truck `padId` plays: its pick, else the office.
	mapOf = function(picks, padId)
		local map: MapId? = if padId ~= nil then picks[padId] else nil
		return if map ~= nil then map else "office"
	end,

	-- The jobs a run on `map` may be.
	contractsOf = function(map)
		return if map == "school" then DepotConstants.SCHOOL_CONTRACTS else DepotConstants.CONTRACTS
	end,

	-- The map whose jobs name `client`; the office for any other client.
	mapOfClient = function(client)
		for _, contract in DepotConstants.SCHOOL_CONTRACTS do
			if contract.client == client then
				return "school"
			end
		end
		return "office"
	end,

	-- `map`'s words during a run.
	siteOf = function(map)
		return if map == "school" then DepotConstants.SCHOOL_SITE else DepotConstants.OFFICE_SITE
	end,
}

return DepotMapRules
