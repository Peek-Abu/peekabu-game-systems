--!strict
--[=[
	LootRules: rolling a weighted loot table. Pure: the random source is passed in, so drops can be seeded
	and tested.

	@class LootRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootTypes = require(ReplicatedStorage.Shared.Features.Loot.Data.LootTypes)

type LootEntry = LootTypes.LootEntry
type Drop = LootTypes.Drop

local LootRules = {}

local function totalWeight(entries: { LootEntry }): number
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	return total
end

--[=[
	The entry a roll in [0, 1) lands on.
]=]
function LootRules.pick(entries: { LootEntry }, roll: number): LootEntry
	local target = math.clamp(roll, 0, 1) * totalWeight(entries)
	local cumulative = 0
	for _, entry in entries do
		cumulative += entry.weight
		if target < cumulative then
			return entry
		end
	end
	return entries[#entries]
end

--[=[
	Rolls the table `rolls` times; repeated ids are merged into one drop.
]=]
function LootRules.roll(lootTable: LootTypes.LootTable, random: LootTypes.RandomSource): { Drop }
	local drops: { Drop } = {}
	local byId: { [string]: Drop } = {}
	for _ = 1, lootTable.rolls or 1 do
		local entry = LootRules.pick(lootTable.entries, random())
		local id = entry.id
		if id ~= nil then
			local min = entry.min or 1
			local max = entry.max or min
			local count = min + math.floor(random() * (max - min + 1))
			count = math.clamp(count, min, max)
			if count > 0 then
				local existing = byId[id]
				if existing ~= nil then
					existing.count += count
				else
					local drop: Drop = { id = id, count = count }
					byId[id] = drop
					table.insert(drops, drop)
				end
			end
		end
	end
	return drops
end

--[=[
	Each id's chance per roll (for a "drop rates" display, which some platforms require).
]=]
function LootRules.chances(lootTable: LootTypes.LootTable): { [string]: number }
	local total = totalWeight(lootTable.entries)
	local chances: { [string]: number } = {}
	for _, entry in lootTable.entries do
		local id = entry.id
		if id ~= nil then
			chances[id] = (chances[id] or 0) + entry.weight / total
		end
	end
	return chances
end

return LootRules
