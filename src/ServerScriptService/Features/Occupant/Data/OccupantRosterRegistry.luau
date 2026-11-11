--!strict
--[=[
	OccupantRosterRegistry: which monster kinds each map can run (the map-agnostic roster, plan
	docs/superpowers/plans/2026-11-11-odd-hours-monster-roster-bramble.md). Per map id: a weighted list of kinds
	(OccupantKindRegistry) and a budget (how many run at once). OccupantRosterRules.pick chooses from it per shift.

	At launch every budget is 1 (Occupant runs one rig; two at once is a later change, the twin guard assumes one):
	the Office runs Harlow, the School runs Bramble.

	@class OccupantRosterRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)

export type Entry = {
	kind: OccupantKindRegistry.KindId,
	-- Relative chance (> 0) against the other entries.
	weight: number,
}

export type Roster = {
	entries: { Entry },
	budget: number,
}

local OFFICE: Roster = { entries = { { kind = "harlow", weight = 1 } }, budget = 1 }
local SCHOOL: Roster = { entries = { { kind = "bramble", weight = 1 } }, budget = 1 }

local ROSTERS: { [string]: Roster } = {
	office = OFFICE,
	school = SCHOOL,
}

local MAP_IDS: { string } = { "office", "school" }

local OccupantRosterRegistry = {}

function OccupantRosterRegistry.get(mapId: string): Roster?
	return ROSTERS[mapId]
end

-- Every map with a roster, sorted.
function OccupantRosterRegistry.mapIds(): { string }
	return table.clone(MAP_IDS)
end

return OccupantRosterRegistry
