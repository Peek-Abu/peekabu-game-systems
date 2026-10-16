--!strict
--[=[
	ShiftResultsUtils: builds the end-of-shift performance review (spec §3 step 7): the shift's totals, the crew
	ordered by what they banked, the overall rating stamp, and the four joke awards (Figma 5a/5c: EMPLOYEE OF THE
	NIGHT, MOST REHIRED, BUTTERFINGERS, and LOUDEST VACUUM or QUIETEST FEET). A stat nobody scored gives no award.
	Ties go to whoever is listed first (more banked, then name). Pure.

	@class ShiftResultsUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

type CrewStats = ShiftTypes.CrewStats
type Lookup = (kind: string) -> CargoTypes.ItemDef?

export type ResultsInput = {
	outcome: string,
	quota: number,
	cleared: number,
	-- The Gloom of `cleared` that came from piles (Round's `dust` counter); absent reads 0.
	dust: number?,
	bonus: number,
	quotaMet: boolean,
	crew: { CrewStats },
	-- Salvage the shift's roll offered (OfficeSpawnUtils.salvageCount).
	offered: number,
	-- The cargo catalog (CargoRegistry.get), for item names in award details.
	lookup: Lookup,
}

local ShiftResultsUtils = {}

-- "once", "twice", "3 times".
function ShiftResultsUtils.times(count: number): string
	if count == 1 then
		return "once"
	elseif count == 2 then
		return "twice"
	end
	return `{count} times`
end

--[=[
	The overall stamp: a missed quota is NEEDS IMPROVEMENT whatever else happened; a met quota is SATISFACTORY, or
	EXCEEDS EXPECTATIONS when at least RATING_EXCEEDS_LOADED of every RATING_EXCEEDS_OF salvage offered was loaded.
	Nothing offered never exceeds.
]=]
function ShiftResultsUtils.rating(quotaMet: boolean, salvage: number, offered: number): ShiftTypes.Rating
	if not quotaMet then
		return "needsImprovement"
	end
	local loaded, of = ShiftConstants.RATING_EXCEEDS_LOADED, ShiftConstants.RATING_EXCEEDS_OF
	if offered > 0 and salvage * of >= offered * loaded then
		return "exceeds"
	end
	return "satisfactory"
end

-- Whoever leads `score` with more than zero (the first in crew order on a tie), and their score.
local function leader(crew: { CrewStats }, score: (member: CrewStats) -> number): (CrewStats?, number)
	local best: CrewStats? = nil
	local bestScore = 0
	for _, member in crew do
		local value = score(member)
		if value > bestScore then
			best = member
			bestScore = value
		end
	end
	return best, bestScore
end

-- Fewest times heard, then fewest noises (the first in crew order on a tie); nil for an empty crew.
local function quietest(crew: { CrewStats }): CrewStats?
	local best: CrewStats? = nil
	for _, member in crew do
		local current = best
		if current == nil then
			best = member
		else
			local woke, bestWoke = member.woke or 0, current.woke or 0
			if woke < bestWoke or (woke == bestWoke and (member.noise or 0) < (current.noise or 0)) then
				best = member
			end
		end
	end
	return best
end

--[=[
	The four joke awards (Figma 5a/5c), from a crew already in crew order: EMPLOYEE OF THE NIGHT (most banked),
	MOST REHIRED (most caught), BUTTERFINGERS (most drops; names the most valuable), and LOUDEST VACUUM when someone
	woke Harlow LOUDEST_MIN_WOKE times, else QUIETEST FEET. A stat nobody scored gives no award.
]=]
function ShiftResultsUtils.awards(crew: { CrewStats }, lookup: Lookup): { ShiftTypes.Award }
	local titles = ShiftConstants.AWARD_TITLES
	local awards: { ShiftTypes.Award } = {}
	local function add(title: string, member: CrewStats, detail: string)
		table.insert(awards, { title = title, name = member.name, userId = member.userId, detail = detail })
	end
	local hauler, hauled = leader(crew, function(member)
		return member.banked
	end)
	if hauler ~= nil then
		add(titles.employee, hauler, `hauled {hauled}`)
	end
	local rehired, caught = leader(crew, function(member)
		return member.caught or 0
	end)
	if rehired ~= nil then
		add(titles.rehired, rehired, `caught {ShiftResultsUtils.times(caught)}`)
	end
	local fumbler, drops = leader(crew, function(member)
		return member.drops or 0
	end)
	if fumbler ~= nil then
		local kind = fumbler.dropKind
		local def = if kind ~= nil then lookup(kind) else nil
		local detail = if def ~= nil
			then `dropped the {string.lower(def.name)}`
			else `dropped things {ShiftResultsUtils.times(drops)}`
		add(titles.butterfingers, fumbler, detail)
	end
	local loudest, woke = leader(crew, function(member)
		return member.woke or 0
	end)
	if loudest ~= nil and woke >= ShiftConstants.LOUDEST_MIN_WOKE then
		add(titles.loudest, loudest, `woke the Manager {ShiftResultsUtils.times(woke)}`)
	else
		local quiet = quietest(crew)
		if quiet ~= nil then
			local heard = quiet.woke or 0
			add(
				titles.quietest,
				quiet,
				if heard == 0 then "never heard once" else `heard {ShiftResultsUtils.times(heard)}`
			)
		end
	end
	return awards
end

-- An empty review: what the shift falls back to when building the real one throws.
function ShiftResultsUtils.bare(outcome: string, quota: number, quotaMet: boolean): ShiftTypes.ShiftResults
	return {
		outcome = outcome,
		quota = quota,
		cleared = 0,
		dust = 0,
		bonus = 0,
		salvage = 0,
		piles = 0,
		catches = 0,
		offered = 0,
		rating = ShiftResultsUtils.rating(quotaMet, 0, 0),
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
	local salvage, piles, catches = 0, 0, 0
	for _, member in crew do
		table.insert(lines, {
			userId = member.userId,
			name = member.name,
			banked = member.banked,
			piles = member.piles,
			salvage = member.salvage,
			caught = member.caught or 0,
			items = member.items or 0,
			overtimeSalvage = member.overtimeSalvage or 0,
		})
		salvage += member.salvage
		piles += member.piles
		catches += member.caught or 0
	end
	return {
		outcome = input.outcome,
		quota = input.quota,
		cleared = input.cleared,
		dust = math.clamp(input.dust or 0, 0, math.max(input.cleared, 0)),
		bonus = input.bonus,
		salvage = salvage,
		piles = piles,
		catches = catches,
		offered = input.offered,
		rating = ShiftResultsUtils.rating(input.quotaMet, salvage, input.offered),
		quotaMet = input.quotaMet,
		crew = lines,
		awards = ShiftResultsUtils.awards(crew, input.lookup),
	}
end

return ShiftResultsUtils
