--!strict
--[=[
	DepotModeRules: the truck's run mode pick (Night Shift, owner concept B 11-18). The host picks Night Shift (nights in
	a row, the default) or Quick shift (one shift) on the START panel beside the place pick; only the host picks (the
	same check as the map, DepotMapRules.canPick). `parse` reads a mode off anything untrusted (a client's pick, the
	depart payload): only an exact mode counts, anything else is ShiftNightConstants.DEFAULT_MODE. `decode` reads the
	published picks (the DepotConstants.MODE_WORLD_ENTRY world entry) on a client, dropping bad entries; `modeOf` is a
	truck's pick, the default when it has none. Pure.

	@class DepotModeRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftNightConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftNightConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)

type RunMode = ShiftTypes.RunMode

-- Each truck's pick, by Queue pad id.
export type Picks = { [string]: RunMode }

-- The mode `value` names, or nil when it names none.
local function modeFrom(value: unknown): RunMode?
	if value == ShiftNightConstants.MODE_NIGHT then
		return "night"
	elseif value == ShiftNightConstants.MODE_QUICK then
		return "quick"
	end
	return nil
end

local function default(): RunMode
	local mode: RunMode? = modeFrom(ShiftNightConstants.DEFAULT_MODE)
	return if mode ~= nil then mode else "night"
end

export type DepotModeRules = {
	isMode: (value: unknown) -> boolean,
	parse: (value: unknown) -> RunMode,
	decode: (value: WorldTypes.WorldValue?) -> Picks,
	modeOf: (picks: Picks, padId: string?) -> RunMode,
}

local DepotModeRules: DepotModeRules = {
	isMode = function(value)
		return modeFrom(value) ~= nil
	end,

	-- The mode `value` names; anything that is not exactly a mode is the default.
	parse = function(value)
		local mode: RunMode? = modeFrom(value)
		return if mode ~= nil then mode else default()
	end,

	-- The picks in the world entry; a bad entry is dropped, a missing or malformed entry is no picks.
	decode = function(value)
		local picks: Picks = {}
		if type(value) ~= "table" then
			return picks
		end
		for key, item in value do
			local mode: RunMode? = modeFrom(item)
			if mode ~= nil and type(key) == "string" then
				picks[key] = mode
			end
		end
		return picks
	end,

	-- The mode truck `padId` plays: its pick, else the default.
	modeOf = function(picks, padId)
		local mode: RunMode? = if padId ~= nil then picks[padId] else nil
		return if mode ~= nil then mode else default()
	end,
}

return DepotModeRules
