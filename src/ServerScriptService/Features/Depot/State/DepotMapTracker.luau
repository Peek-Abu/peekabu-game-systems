--!strict
--[=[
	DepotMapTracker: which map each truck's host picked (the School map plan), keyed by Queue pad id. A truck nobody
	picked for plays the office. DepotServiceServer records a host's accepted pick (DepotMapRules.canPick), clears a
	truck's pick when its party departs (after Queue has read it into the depart data), and every tick keeps only the
	trucks that still have a host (`retain`), so an emptied truck starts over on the office. `snapshot` is the
	DepotConstants.MAP_WORLD_ENTRY world entry (decoded on clients by DepotMapRules.decode). Plain bookkeeping.

	@class DepotMapTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)

type MapId = ShiftTypes.MapId

export type DepotMapTracker = {
	pick: (self: DepotMapTracker, padId: string, map: MapId) -> boolean,
	mapOf: (self: DepotMapTracker, padId: string) -> MapId,
	clear: (self: DepotMapTracker, padId: string) -> boolean,
	retain: (self: DepotMapTracker, live: { [string]: boolean }) -> boolean,
	reset: (self: DepotMapTracker) -> (),
	snapshot: (self: DepotMapTracker) -> WorldTypes.WorldTable,
}

local DepotMapTracker = {}

function DepotMapTracker.new(): DepotMapTracker
	local picks: { [string]: MapId } = {}

	local tracker: DepotMapTracker = {
		-- Records truck `padId`'s pick. Whether it changed.
		pick = function(_self, padId, map)
			if picks[padId] == map then
				return false
			end
			picks[padId] = map
			return true
		end,

		mapOf = function(_self, padId)
			return picks[padId] or "office"
		end,

		-- Forgets truck `padId`'s pick. Whether it had one.
		clear = function(_self, padId)
			if picks[padId] == nil then
				return false
			end
			picks[padId] = nil
			return true
		end,

		-- Forgets the picks of every truck not in `live`. Whether any went.
		retain = function(_self, live)
			local changed = false
			for padId in picks do
				if live[padId] ~= true then
					picks[padId] = nil
					changed = true
				end
			end
			return changed
		end,

		reset = function(_self)
			table.clear(picks)
		end,

		snapshot = function(_self)
			local entry: WorldTypes.WorldTable = table.clone(picks)
			return entry
		end,
	}
	return tracker
end

return DepotMapTracker
