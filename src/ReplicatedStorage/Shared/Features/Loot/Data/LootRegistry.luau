--!strict
--[=[
	LootRegistry: weighted loot tables by id (the ItemRegistry contract: validated, loud at boot). Shared,
	so a client can show what a chest may contain.

	@class LootRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootTypes = require(ReplicatedStorage.Shared.Features.Loot.Data.LootTypes)

local tables: { [string]: LootTypes.LootTable } = {}

local function isWhole(value: number, least: number): boolean
	return value >= least and value == math.floor(value)
end

local LootRegistry = {}

--[=[
	Registers a table. Asserts: a new id; at least one entry; positive weights; each entry is either an
	`id` or `nothing`; whole counts with 0 ≤ min ≤ max; whole rolls ≥ 1.
]=]
function LootRegistry.register(id: string, lootTable: LootTypes.LootTable)
	assert(id ~= "", "a loot table needs an id")
	assert(tables[id] == nil, `loot table "{id}" is already registered`)
	assert(#lootTable.entries > 0, `loot table "{id}" has no entries`)
	local rolls = lootTable.rolls
	assert(rolls == nil or isWhole(rolls, 1), `loot table "{id}": rolls must be a whole number of at least 1`)
	for index, entry in lootTable.entries do
		local label = `loot table "{id}" entry {index}`
		assert(entry.weight > 0, `{label}: weight must be positive`)
		assert((entry.id ~= nil) ~= (entry.nothing == true), `{label}: needs an id or nothing = true, not both`)
		local min = entry.min or 1
		local max = entry.max or min
		assert(isWhole(min, 0) and isWhole(max, 0) and min <= max, `{label}: counts must be whole with min <= max`)
	end
	tables[id] = table.freeze(table.clone(lootTable))
end

function LootRegistry.get(id: string): LootTypes.LootTable?
	return tables[id]
end

return LootRegistry
