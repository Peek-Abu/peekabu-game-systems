--!strict
--[=[
	LootTypes: weighted loot tables (design: docs/superpowers/specs/2026-10-09-small-services-design.md).

	@class LootTypes
]=]

-- One weighted outcome: `id` (what it means is the game's — an item type, a currency, an egg kind) with a
-- count from min to max (default 1), or `nothing`.
export type LootEntry = {
	id: string?,
	nothing: boolean?,
	weight: number,
	min: number?,
	max: number?,
}

-- `rolls` picks per roll of the table (default 1).
export type LootTable = {
	rolls: number?,
	entries: { LootEntry },
}

export type Drop = { id: string, count: number }

-- A random source returning a number in [0, 1).
export type RandomSource = () -> number

return {}
