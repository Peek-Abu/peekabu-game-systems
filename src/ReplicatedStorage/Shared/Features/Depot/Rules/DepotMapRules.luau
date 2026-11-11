--!strict
--[=[
	DepotMapRules: the truck's map pick (the School map plan). Only a truck's host picks its map (`canPick`; the host is
	crew hosting's, HostServiceServer:hostOf); the maps are OFFICE and SCHOOL (`MAPS`, in card order). `parse` reads a
	map off anything untrusted (the depart payload riding the teleport, a client's pick): only an exact map id counts,
	anything else is the office. `decode` reads the published picks (the DepotConstants.MAP_WORLD_ENTRY world entry) on
	a client, dropping bad entries; `mapOf` is a truck's pick, the office when it has none.

	@class DepotMapRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)

type MapId = ShiftTypes.MapId

-- Each truck's pick, by Queue pad id.
export type Picks = { [string]: MapId }

local MAPS: { MapId } = { "office", "school" }

local DepotMapRules = {
	MAPS = table.freeze(MAPS),
}

-- The map `value` names, or nil when it names none.
local function mapFrom(value: unknown): MapId?
	if value == "office" then
		return "office"
	elseif value == "school" then
		return "school"
	end
	return nil
end

function DepotMapRules.isMap(value: unknown): boolean
	return mapFrom(value) ~= nil
end

-- The map `value` names; anything that is not exactly a map id is the office.
function DepotMapRules.parse(value: unknown): MapId
	local map: MapId? = mapFrom(value)
	return if map ~= nil then map else "office"
end

-- Whether `userId` may pick the map of a truck hosted by `host` (nil: nobody hosts it).
function DepotMapRules.canPick(userId: number, host: number?): boolean
	return host ~= nil and userId == host
end

-- The picks in the world entry; a bad entry is dropped, a missing or malformed entry is no picks.
function DepotMapRules.decode(value: WorldTypes.WorldValue?): Picks
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
end

-- The map truck `padId` plays: its pick, else the office.
function DepotMapRules.mapOf(picks: Picks, padId: string?): MapId
	local map: MapId? = if padId ~= nil then picks[padId] else nil
	return if map ~= nil then map else "office"
end

return DepotMapRules
