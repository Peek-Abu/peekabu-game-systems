--!strict
--[=[
	ShiftReviewViewModel: the performance review (Figma 5a met, 5c missed, 5b phone): the QUOTA MET / MISSED headline
	stamp, the four rows, the rating stamp (a missed quota never rates above NEEDS IMPROVEMENT) and Harlow's (or HR's)
	closing line, the joke awards ("you" by userId, never by name; the phone shows two and folds the rest), and the
	crew vote (counts against the crew, your vote marked in words, the auto-pick countdown); and `fit`, the scale that
	keeps the review sheet on a smaller screen; and `reopen`, the manila tab that brings the review back after Escape
	closed it while the vote still runs. Pure.

	@class ShiftReviewViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

export type RowView = { label: string, value: string }
export type AwardView = { title: string, line: string }
export type VoteView = {
	label: string,
	count: number,
	total: number,
	mine: boolean,
	-- The phone button's text: the label and the count ("ANOTHER SHIFT  2/3").
	text: string,
	-- "your vote" in marker ink beside the choice the local player made; nil otherwise.
	mark: string?,
}

export type ReviewView = {
	tab: string,
	subtitle: string,
	headline: string,
	met: boolean,
	rows: { RowView },
	ratingLabel: string,
	rating: string,
	quote: string,
	quoteBy: string,
	-- The awards drawn first (all four on desktop, two on the phone).
	awards: { AwardView },
	-- The phone's folded awards, its "+2 MORE AWARDS" button and the label that folds them away again.
	extraAwards: { AwardView },
	moreAwards: string?,
	lessAwards: string?,
	voteTitle: string,
	another: VoteView,
	depot: VoteView,
	footer: string,
}

local PHONE_AWARDS = 2
local YOUR_VOTE = "your vote"

-- The review's drawn size per device (Figma 5a: the 1600x900 folder under its 46 px tab; 5b: the 748x358 folder
-- filling the 844x390 phone's safe area) and the screen margins it keeps (the safe areas across, the top bar and
-- bottom inset down).
local SHEET = table.freeze({
	desktop = table.freeze({ width = 1600, height = 946, marginX = 120, marginY = 98 }),
	phone = table.freeze({ width = 748, height = 358, marginX = 96, marginY = 32 }),
})

local ShiftReviewViewModel = {}

-- The smallest scale `fit` returns (a degenerate viewport still draws something readable to vote on).
ShiftReviewViewModel.MIN_SCALE = 0.4

-- The scale the review is drawn at on a `viewport`-sized screen: 1 when it fits, else the tighter side's ratio.
function ShiftReviewViewModel.fit(viewport: Vector2, phone: boolean): number
	local sheet = if phone then SHEET.phone else SHEET.desktop
	local across = (viewport.X - sheet.marginX) / sheet.width
	local down = (viewport.Y - sheet.marginY) / sheet.height
	return math.clamp(math.min(across, down), ShiftReviewViewModel.MIN_SCALE, 1)
end

local function vote(label: string, count: number, total: number, mine: boolean): VoteView
	return {
		label = label,
		count = count,
		total = total,
		mine = mine,
		text = `{label}  {count}/{total}`,
		mark = if mine then YOUR_VOTE else nil,
	}
end

local function awardOf(award: ShiftTypes.Award, myUserId: number, phone: boolean): AwardView
	local name = if myUserId ~= 0 and award.userId == myUserId then "you" else award.name
	local line = if phone or award.detail == "" then name else `{name} — {award.detail}`
	return { title = award.title, line = line }
end

--[=[
	The review while the crew votes; nil outside results or before the review arrives. `myVote` is ShiftStore.myVote,
	`myUserId` the local player's (0 matches nobody), `now` the server clock, `phone` the 5b layout.
]=]
function ShiftReviewViewModel.review(
	snapshot: ShiftTypes.ShiftSnapshot?,
	myVote: string?,
	myUserId: number,
	now: number,
	phone: boolean
): ReviewView?
	if snapshot == nil or snapshot.phase ~= "results" then
		return nil
	end
	local results = snapshot.results
	if results == nil then
		return nil
	end
	local met = results.quotaMet
	local quote = if met then ShiftConstants.REVIEW_QUOTES.met else ShiftConstants.REVIEW_QUOTES.missed
	local rating: string = if met then results.rating else "needsImprovement"
	local awards: { AwardView } = {}
	local extraAwards: { AwardView } = {}
	for index, award in results.awards do
		local folded = phone and index > PHONE_AWARDS
		table.insert(if folded then extraAwards else awards, awardOf(award, myUserId, phone))
	end
	local extra = #extraAwards
	local total = math.max(#snapshot.crew, snapshot.votesAnother + snapshot.votesDepot, 1)
	local voteEndsAt = snapshot.voteEndsAt
	local left = ShiftHudViewModel.clock(if voteEndsAt ~= nil then voteEndsAt - now else 0)
	local truck = snapshot.truck
	local crewText = if truck ~= nil then `Crew of Truck {truck}` else "Crew"
	return {
		tab = if phone then "PERFORMANCE REVIEW" else "PERFORMANCE REVIEW — NIGHT SHIFT",
		subtitle = `{crewText} · {DepotConstants.CONTRACTS[1].client} · {DepotConstants.SITE}`,
		headline = if met then "QUOTA MET" else "QUOTA MISSED",
		met = met,
		rows = {
			{ label = "CLEARED", value = `{results.cleared} / {results.quota}` },
			{ label = if met then "FINDER'S FEE" else "FINDER'S FEE (banked)", value = `+{results.bonus}` },
			{ label = "TIMES CAUGHT", value = tostring(results.catches) },
			{ label = "SALVAGE FOUND", value = `{results.salvage} of {results.offered}` },
		},
		ratingLabel = if phone then "Rating:" else "Overall rating:",
		rating = ShiftConstants.RATING_TEXT[rating] or rating,
		quote = quote.line,
		quoteBy = quote.by,
		awards = awards,
		extraAwards = extraAwards,
		moreAwards = if extra > 0 then `+{extra} MORE AWARDS` else nil,
		lessAwards = if extra > 0 then `FIRST {PHONE_AWARDS} AWARDS` else nil,
		voteTitle = if phone then "WHAT NEXT?" else "WHAT NEXT? (crew vote)",
		another = vote("ANOTHER SHIFT", snapshot.votesAnother, total, myVote == "another"),
		depot = vote("BACK TO DEPOT", snapshot.votesDepot, total, myVote == "depot"),
		footer = if phone
			then `Majority decides · auto-picks in {left}\nA tie means Another shift`
			else `Majority decides · auto-picks in {left} · a tie means Another shift`,
	}
end

--[=[
	The reopen tab's text while the crew votes on a review that is not on the scene `stack` (Escape closed it); nil
	while the review is open, outside results, or before the review arrives.
]=]
function ShiftReviewViewModel.reopen(snapshot: ShiftTypes.ShiftSnapshot?, stack: { string }): string?
	if snapshot == nil or snapshot.phase ~= "results" or snapshot.results == nil then
		return nil
	end
	if table.find(stack, ShiftConstants.REVIEW_SCENE) ~= nil then
		return nil
	end
	return "PERFORMANCE REVIEW · OPEN"
end

return ShiftReviewViewModel
