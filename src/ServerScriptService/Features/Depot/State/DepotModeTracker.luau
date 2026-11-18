--!strict
--[=[
	DepotModeTracker: which run mode each truck's host picked (Night Shift or Quick shift), keyed by Queue pad id. A
	truck nobody picked for plays the default (DepotModeRules.parse(nil), Night Shift). DepotMapSystem records a host's
	accepted pick, clears a truck's pick when its party departs (after Queue has read it into the depart data), and
	every tick keeps only the trucks that still have a host (`retain`), so an emptied truck starts over on the default.
	`snapshot` is the DepotConstants.MODE_WORLD_ENTRY world entry (decoded on clients by DepotModeRules.decode). Plain
	bookkeeping.

	@class DepotModeTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotModeRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotModeRules)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)

type RunMode = ShiftTypes.RunMode

export type DepotModeTracker = {
	pick: (self: DepotModeTracker, padId: string, mode: RunMode) -> boolean,
	modeOf: (self: DepotModeTracker, padId: string) -> RunMode,
	clear: (self: DepotModeTracker, padId: string) -> boolean,
	retain: (self: DepotModeTracker, live: { [string]: boolean }) -> boolean,
	reset: (self: DepotModeTracker) -> (),
	snapshot: (self: DepotModeTracker) -> WorldTypes.WorldTable,
}

local DepotModeTracker = {}

function DepotModeTracker.new(): DepotModeTracker
	local picks: DepotModeRules.Picks = {}

	local tracker: DepotModeTracker = {
		-- Records truck `padId`'s pick. Whether it changed.
		pick = function(_self, padId, mode)
			if picks[padId] == mode then
				return false
			end
			picks[padId] = mode
			return true
		end,

		modeOf = function(_self, padId)
			return DepotModeRules.modeOf(picks, padId)
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

return DepotModeTracker
