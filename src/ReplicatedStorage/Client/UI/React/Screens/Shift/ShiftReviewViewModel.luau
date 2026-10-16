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
local ShiftCurrencyUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftCurrencyUtils)
local ShiftQuotaFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftQuotaFormulas)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

-- A totals row; `detail` is its breakdown line under the label (desktop), e.g. "Dust 260 · Item cleaning 80".
export type RowView = { label: string, value: string, detail: string? }
export type AwardSymbol = "medal" | "punchCard" | "droppedMug" | "quietShoe" | "noisyVacuum"
export type AwardShape = {
	x: number,
	y: number,
	w: number,
	h: number,
	rotation: number,
	round: number,
	color: "companyTeal" | "manila" | "cream" | "ink" | "stamp",
}
export type AwardView = { title: string, line: string, symbol: AwardSymbol?, userId: number? }
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
	-- Whether a vote can still be cast (until the vote closes at 0:00); the buttons are disabled after.
	voteOpen: boolean,
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

function ShiftReviewViewModel.awardSymbol(title: string): AwardSymbol?
	local titles = ShiftConstants.AWARD_TITLES
	if title == titles.employee then
		return "medal"
	elseif title == titles.rehired then
		return "punchCard"
	elseif title == titles.butterfingers then
		return "droppedMug"
	elseif title == titles.quietest then
		return "quietShoe"
	elseif title == titles.loudest then
		return "noisyVacuum"
	end
	return nil
end
local AWARD_SHAPES: { [AwardSymbol]: { AwardShape } } = {
	medal = {
		{ x = 17, y = 30, w = 13, h = 27, color = "companyTeal", rotation = 17, round = 0 },
		{ x = 34, y = 30, w = 13, h = 27, color = "companyTeal", rotation = -17, round = 0 },
		{ x = 11, y = 7, w = 42, h = 42, color = "ink", rotation = 0, round = 1 },
		{ x = 14, y = 10, w = 36, h = 36, color = "manila", rotation = 0, round = 1 },
		{ x = 21, y = 17, w = 22, h = 22, color = "cream", rotation = 0, round = 1 },
		{ x = 26, y = 22, w = 12, h = 12, color = "companyTeal", rotation = 45, round = 0 },
	},
	punchCard = {
		{ x = 12, y = 6, w = 40, h = 52, color = "ink", rotation = -4, round = 0 },
		{ x = 15, y = 9, w = 34, h = 46, color = "cream", rotation = -4, round = 0 },
		{ x = 17, y = 14, w = 30, h = 9, color = "companyTeal", rotation = -4, round = 0 },
		{ x = 20, y = 29, w = 5, h = 5, color = "manila", rotation = 0, round = 1 },
		{ x = 30, y = 29, w = 5, h = 5, color = "manila", rotation = 0, round = 1 },
		{ x = 40, y = 29, w = 5, h = 5, color = "stamp", rotation = 0, round = 1 },
		{ x = 20, y = 41, w = 5, h = 5, color = "manila", rotation = 0, round = 1 },
		{ x = 30, y = 41, w = 5, h = 5, color = "stamp", rotation = 0, round = 1 },
		{ x = 39, y = 42, w = 13, h = 6, color = "companyTeal", rotation = -25, round = 0 },
	},
	droppedMug = {
		{ x = 37, y = 18, w = 19, h = 22, color = "ink", rotation = 12, round = 1 },
		{ x = 40, y = 21, w = 13, h = 16, color = "cream", rotation = 12, round = 1 },
		{ x = 11, y = 15, w = 18, h = 31, color = "ink", rotation = -12, round = 0 },
		{ x = 13, y = 17, w = 14, h = 27, color = "cream", rotation = -12, round = 0 },
		{ x = 29, y = 19, w = 12, h = 28, color = "ink", rotation = 13, round = 0 },
		{ x = 31, y = 21, w = 8, h = 24, color = "cream", rotation = 13, round = 0 },
		{ x = 9, y = 49, w = 14, h = 5, color = "companyTeal", rotation = 10, round = 0 },
		{ x = 27, y = 52, w = 12, h = 5, color = "companyTeal", rotation = -10, round = 0 },
		{ x = 43, y = 48, w = 6, h = 7, color = "cream", rotation = 30, round = 0 },
	},
	quietShoe = {
		{ x = 15, y = 12, w = 17, h = 25, color = "ink", rotation = -8, round = 0 },
		{ x = 17, y = 14, w = 13, h = 22, color = "cream", rotation = -8, round = 0 },
		{ x = 11, y = 33, w = 39, h = 15, color = "ink", rotation = -5, round = 1 },
		{ x = 14, y = 33, w = 34, h = 10, color = "companyTeal", rotation = -5, round = 1 },
		{ x = 11, y = 46, w = 42, h = 6, color = "manila", rotation = -5, round = 1 },
		{ x = 19, y = 34, w = 3, h = 7, color = "cream", rotation = -25, round = 0 },
		{ x = 26, y = 33, w = 3, h = 7, color = "cream", rotation = -25, round = 0 },
		{ x = 46, y = 15, w = 9, h = 3, color = "companyTeal", rotation = -25, round = 0 },
		{ x = 50, y = 23, w = 9, h = 3, color = "companyTeal", rotation = -25, round = 0 },
	},
	noisyVacuum = {
		{ x = 13, y = 9, w = 22, h = 5, color = "ink", rotation = 0, round = 0 },
		{ x = 13, y = 9, w = 5, h = 12, color = "ink", rotation = 0, round = 0 },
		{ x = 30, y = 9, w = 5, h = 12, color = "ink", rotation = 0, round = 0 },
		{ x = 10, y = 20, w = 29, h = 26, color = "ink", rotation = 0, round = 0.2 },
		{ x = 12, y = 22, w = 25, h = 22, color = "companyTeal", rotation = 0, round = 0.2 },
		{ x = 18, y = 28, w = 13, h = 7, color = "cream", rotation = 0, round = 0 },
		{ x = 12, y = 44, w = 6, h = 12, color = "manila", rotation = 20, round = 0 },
		{ x = 7, y = 53, w = 28, h = 5, color = "ink", rotation = 0, round = 0 },
		{ x = 44, y = 17, w = 12, h = 4, color = "manila", rotation = -30, round = 0 },
		{ x = 46, y = 30, w = 14, h = 4, color = "manila", rotation = 0, round = 0 },
		{ x = 44, y = 43, w = 12, h = 4, color = "manila", rotation = 30, round = 0 },
	},
}
function ShiftReviewViewModel.awardShapes(symbol: AwardSymbol): { AwardShape }
	return AWARD_SHAPES[symbol]
end

function ShiftReviewViewModel.shapesForAward(title: string): { AwardShape }
	local symbol: AwardSymbol? = ShiftReviewViewModel.awardSymbol(title)
	return if symbol ~= nil then ShiftReviewViewModel.awardShapes(symbol) else {}
end

local function awardOf(award: ShiftTypes.Award, myUserId: number, phone: boolean): AwardView
	local name = if myUserId ~= 0 and award.userId == myUserId then "you" else award.name
	local line = if phone or award.detail == "" then name else `{name} — {award.detail}`
	return {
		title = award.title,
		line = line,
		symbol = ShiftReviewViewModel.awardSymbol(award.title),
		userId = if award.userId > 0 then award.userId else nil,
	}
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
	local rating: ShiftTypes.Rating = if met then results.rating else "needsImprovement"
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
	-- The pay (docs/superpowers/specs/2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §5): every Gloom removed,
	-- from dust and from cleaning valuables, plus the valuables banked; paid whether or not the contract was met.
	local split = ShiftQuotaFormulas.breakdown(results.cleared, results.dust or 0, results.bonus)
	local crewText = if truck ~= nil then `Crew of Truck {truck}` else "Crew"
	return {
		tab = if phone then "PERFORMANCE REVIEW" else "PERFORMANCE REVIEW — NIGHT SHIFT",
		subtitle = `{crewText} · {DepotConstants.CONTRACTS[1].client} · {DepotConstants.SITE}`,
		headline = if met then "CONTRACT MET" else "CONTRACT MISSED",
		met = met,
		rows = {
			{
				label = "GLOOM REMOVED",
				value = `{split.gloom} / {results.quota}`,
				detail = `Dust {split.dust} · Item cleaning {split.grime}`,
			},
			{
				label = ShiftCurrencyUtils.earnedLabel(),
				value = ShiftCurrencyUtils.amount(split.gleam),
				detail = `Dust {split.dustGleam} · Cleaning {split.grimeGleam} · Valuables {split.valuables}`,
			},
			{ label = "TIMES CAUGHT", value = tostring(results.catches) },
			{ label = "ASSETS RECOVERED", value = `{results.salvage} of {results.offered}` },
		},
		ratingLabel = if phone then "Rating:" else "Overall rating:",
		rating = ShiftConstants.RATING_TEXT[rating] or ShiftConstants.RATING_TEXT.needsImprovement,
		quote = quote.line,
		quoteBy = quote.by,
		awards = awards,
		extraAwards = extraAwards,
		moreAwards = if extra > 0 then `+{extra} MORE AWARDS` else nil,
		lessAwards = if extra > 0 then `FIRST {PHONE_AWARDS} AWARDS` else nil,
		voteOpen = voteEndsAt == nil or now < voteEndsAt,
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
