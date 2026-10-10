--!strict
--[=[
	ShiftResultsUtils: builds the end-of-shift performance review (spec §3 step 7; plain in M1, the joke
	awards grow in M3): the shift's totals, the crew ordered by what they banked, and an award per category
	(most banked, most piles, most salvage) for whoever leads it with more than zero. Ties go to whoever is
	listed first (more banked, then name). Pure.

	@class ShiftResultsUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type CrewStats = ShiftTypes.CrewStats

export type ResultsInput = {
	outcome: string,
	quota: number,
	cleared: number,
	bonus: number,
	quotaMet: boolean,
	crew: { CrewStats },
}

local ShiftResultsUtils = {}

-- An empty review: what the shift falls back to when building the real one throws.
function ShiftResultsUtils.bare(outcome: string, quota: number, quotaMet: boolean): ShiftTypes.ShiftResults
	return {
		outcome = outcome,
		quota = quota,
		cleared = 0,
		bonus = 0,
		salvage = 0,
		piles = 0,
		quotaMet = quotaMet,
		crew = {},
		awards = {},
	}
end

function ShiftResultsUtils.build(input: ResultsInput): ShiftTypes.ShiftResults
	local crew = table.clone(input.crew)
	table.sort(crew, function(a, b)
		if a.banked ~= b.banked then
			return a.banked > b.banked
		end
		return a.name < b.name
	end)

	local lines: { ShiftTypes.CrewLine } = {}
	local salvage = 0
	local piles = 0
	for _, member in crew do
		table.insert(
			lines,
			{ name = member.name, banked = member.banked, piles = member.piles, salvage = member.salvage }
		)
		salvage += member.salvage
		piles += member.piles
	end

	local awards: { ShiftTypes.Award } = {}
	local function award(title: string, score: (member: CrewStats) -> number)
		local best: CrewStats? = nil
		local bestScore = 0
		for _, member in crew do
			local value = score(member)
			if value > bestScore then
				best = member
				bestScore = value
			end
		end
		if best ~= nil then
			table.insert(awards, { title = title, name = best.name })
		end
	end
	award("Top Hauler", function(member)
		return member.banked
	end)
	award("Dust Devil", function(member)
		return member.piles
	end)
	award("Treasure Hunter", function(member)
		return member.salvage
	end)

	return {
		outcome = input.outcome,
		quota = input.quota,
		cleared = input.cleared,
		bonus = input.bonus,
		salvage = salvage,
		piles = piles,
		quotaMet = input.quotaMet,
		crew = lines,
		awards = awards,
	}
end

return ShiftResultsUtils
