--!strict
--[=[
	OccupantRosterRules: which monster kind(s) a shift runs (the map-agnostic roster, plan
	docs/superpowers/plans/2026-11-11-odd-hours-monster-roster-bramble.md). `pick` draws up to a roster's budget of
	distinct kinds from its weighted entries with the shift's seed (the same seed, the same kinds); `kindFor` is the
	one kind a map runs at launch (budget 1; Harlow for a map with no roster). `valid` checks a roster's shape.

	Pure: a seeded Random, nothing else.

	@class OccupantRosterRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantKindRegistry = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantKindRegistry)
local OccupantRosterRegistry = require(ServerScriptService.Features.Occupant.Data.OccupantRosterRegistry)

type KindId = OccupantKindRegistry.KindId
type Entry = OccupantRosterRegistry.Entry
type Roster = OccupantRosterRegistry.Roster

local OccupantRosterRules = {}

--[=[
	Up to `roster.budget` distinct kinds, each drawn by weight from the entries left (an entry with no weight is never
	drawn), from `seed`.
]=]
function OccupantRosterRules.pick(roster: Roster, seed: number): { KindId }
	local rng = Random.new(seed)
	local left: { Entry } = {}
	for _, entry in roster.entries do
		if entry.weight > 0 then
			table.insert(left, entry)
		end
	end
	local picked: { KindId } = {}
	while #picked < roster.budget and #left > 0 do
		local total = 0
		for _, entry in left do
			total += entry.weight
		end
		local roll = rng:NextNumber() * total
		local index = #left
		for at, entry in left do
			roll -= entry.weight
			if roll < 0 then
				index = at
				break
			end
		end
		table.insert(picked, left[index].kind)
		table.remove(left, index)
	end
	return picked
end

--[=[
	The kind map `mapId` runs this shift (its roster's first pick from `seed`); Harlow for a map with no roster or an
	empty pick.
]=]
function OccupantRosterRules.kindFor(mapId: string, seed: number): KindId
	local roster = OccupantRosterRegistry.get(mapId)
	local kinds = if roster ~= nil then OccupantRosterRules.pick(roster, seed) else {}
	return kinds[1] or OccupantKindRegistry.DEFAULT
end

--[=[
	Whether a roster names only registered kinds, each once with a positive weight, and has a budget of at least 1.
]=]
function OccupantRosterRules.valid(roster: Roster): boolean
	if roster.budget < 1 then
		return false
	end
	local seen: { [string]: boolean } = {}
	for _, entry in roster.entries do
		if not OccupantKindRegistry.has(entry.kind) or entry.weight <= 0 or seen[entry.kind] then
			return false
		end
		seen[entry.kind] = true
	end
	return true
end

-- Whether every registered roster is valid.
function OccupantRosterRules.allValid(): boolean
	for _, mapId in OccupantRosterRegistry.mapIds() do
		local roster = OccupantRosterRegistry.get(mapId)
		if roster == nil or not OccupantRosterRules.valid(roster) then
			return false
		end
	end
	return true
end

return OccupantRosterRules
