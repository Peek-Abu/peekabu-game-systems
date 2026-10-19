--!strict
--[=[
	ExperimentRegistry: the launch A/B experiments (week-1 analytics). Each has an id, a board name, the unit it
	is assigned by (a player, or a crew for mechanics the whole crew shares) and exactly two variants.
	`variants[1]` is the option listed first on the board; other plans use these exact variant strings.

	@class ExperimentRegistry
]=]

export type Unit = "player" | "crew"

export type Definition = {
	id: string,
	name: string,
	unit: Unit,
	variants: { string },
}

local function define(id: string, name: string, unit: Unit, first: string, second: string): Definition
	return table.freeze({ id = id, name = name, unit = unit, variants = table.freeze({ first, second }) })
end

-- Board order.
local DEFINITIONS: { Definition } = table.freeze({
	define("exp-rehire", "Rehire countdown after the 3rd layer", "crew", "5s", "10s"),
	define("exp-clean", "Time to clean a layer off a teammate", "crew", "1.5s", "3s"),
	define("exp-tutorial", "Tutorial length", "player", "3beats", "5beats"),
	define("exp-friendskip", "Friends skip the tutorial", "crew", "skip", "forced"),
	define("exp-unlock", "Site unlock pace", "player", "after3", "after6"),
	define("exp-employee2", "Second employee timing", "player", "first", "day2"),
	define("exp-stars", "Premium (Gleam) price ladder", "player", "steep", "flat"),
	define("exp-coffee", "Coffee for the crew", "player", "1shift", "10min"),
	define("exp-starter", "Starter pack placement", "player", "success", "hubonly"),
	define("exp-timecard", "Timecard", "player", "5of7", "streak7"),
	define("exp-locker", "Locker pity", "player", "pity10-50", "pity8-40"),
})

local BY_ID: { [string]: Definition } = {}
for _, definition in DEFINITIONS do
	BY_ID[definition.id] = definition
end
table.freeze(BY_ID)

local ExperimentRegistry = {}

function ExperimentRegistry.get(id: string): Definition?
	return BY_ID[id]
end

--[=[
	Every experiment id, in board order (a fresh copy).
]=]
function ExperimentRegistry.ids(): { string }
	local ids: { string } = {}
	for _, definition in DEFINITIONS do
		table.insert(ids, definition.id)
	end
	return ids
end

--[=[
	Every definition, in board order (a fresh list of the frozen definitions).
]=]
function ExperimentRegistry.list(): { Definition }
	return table.clone(DEFINITIONS)
end

return ExperimentRegistry
