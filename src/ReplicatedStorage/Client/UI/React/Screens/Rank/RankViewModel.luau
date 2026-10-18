--!strict
--[=[
	RankViewModel: what the company rank's UI shows (Cleanup Crew "Clearance Level"). Pure.

	- `rankOf`: a player's XP (and the XP before their latest award) off the public entries
	  (RankConstants.PUBLIC_XP_FIELD / PUBLIC_PREV_XP_FIELD); nil until the server has published it.
	- `slip`: the results card's rank slip (RankSlip): level, bar, XP, "Next: ...", this shift's XP breakdown (the
	  shared RankFormulas over the published review, the same numbers the server paid), the incident line for a
	  caught player, and PROMOTED once an award that crossed a level has landed.

	@class RankViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local RankConstants = require(ReplicatedStorage.Shared.Features.Rank.Data.RankConstants)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

export type Rank = {
	xp: number,
	prevXp: number,
}

export type SlipView = {
	heading: string,
	rank: string,
	-- 0..1 of the way to the next level.
	fill: number,
	xpText: string,
	next: string,
	lanyard: Color3,
	-- This shift (absent without a review the player is on).
	gain: string?,
	breakdown: string?,
	incident: string?,
	promoted: boolean,
}

local RankViewModel = {}

function RankViewModel.rankOf(publicPlayers: PublicPlayerTypes.PublicPlayerMap, userId: number): Rank?
	local entry = publicPlayers[tostring(userId)]
	if entry == nil then
		return nil
	end
	local xp = entry[RankConstants.PUBLIC_XP_FIELD]
	if type(xp) ~= "number" then
		return nil
	end
	local prev = entry[RankConstants.PUBLIC_PREV_XP_FIELD]
	return { xp = xp, prevXp = if type(prev) == "number" then prev else xp }
end

function RankViewModel.slip(
	rank: Rank?,
	results: ShiftTypes.ShiftResults?,
	present: { number },
	userId: number
): SlipView?
	if rank == nil then
		return nil
	end
	local progress = RankFormulas.progress(rank.xp)
	local level = progress.level
	local nextLevel = progress.next
	local view: SlipView = {
		heading = `CLEARANCE LEVEL {level.level}`,
		rank = string.upper(level.name),
		fill = progress.fill,
		xpText = if nextLevel ~= nil then `{rank.xp} / {nextLevel.xp} XP` else `{rank.xp} XP`,
		next = if nextLevel ~= nil
			then `Next: {nextLevel.name} ({nextLevel.lanyardName} lanyard) at {nextLevel.xp} XP`
			else "Top of the ladder (for now)",
		lanyard = level.lanyard,
		promoted = false,
	}
	local facts = if results ~= nil
		then RankFormulas.factsFor(RankFormulas.entriesOf(results), results.quotaMet, present, userId, results.outcome)
		else nil
	if facts ~= nil then
		local award = RankFormulas.award(facts)
		local parts: { string } = {}
		for _, line in award.lines do
			table.insert(parts, `{line.label} +{line.xp}`)
		end
		view.gain = `+{award.total} XP this shift`
		view.breakdown = table.concat(parts, " · ")
		view.incident = if award.incident then RankConstants.INCIDENT_LINE else nil
		view.promoted = award.total > 0
			and rank.xp - rank.prevXp == award.total
			and RankFormulas.levelFor(rank.prevXp).level < level.level
	end
	return view
end

return RankViewModel
