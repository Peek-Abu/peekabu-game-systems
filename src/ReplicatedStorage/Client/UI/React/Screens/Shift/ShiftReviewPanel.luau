--!strict
--[=[
	ShiftReviewPanel: the performance review (Figma 5a met 31:557, 5c missed 31:611, 5b phone 31:665) on the paperwork
	look: a manila folder over the dimmed office with its tab, the crew line, the QUOTA MET / MISSED stamp, the four
	rows, "Overall rating:" and its stamp, Harlow's (or HR's) closing line; a fold; the joke-award sticky notes; and the
	crew vote (ANOTHER SHIFT / BACK TO DEPOT with vote dots on desktop, counts on the phone, "your vote" in marker ink
	beside the local player's choice) and its footer. The folder is drawn at its Figma size and positions and scaled
	by `scale` (ShiftReviewViewModel.fit), centred. On the phone "+2 MORE AWARDS" swaps the two stickies for the
	folded ones (UI-only state). With a `rank` view, the company rank's slip (RankSlip: level, XP bar, "Next: ...",
	this shift's XP) is typed under the overall rating on desktop (Harlow's line moves down to make room) and along
	the foot of the right column on the phone. Presentational: it draws the view it is given.

	Tilts are the Figma rotations with the sign flipped (Figma turns counter-clockwise, Roblox clockwise).

	@class ShiftReviewPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local PaperButton = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperButton)
local PaperAwardIcon = require(script.Parent.Parent.Paper.PaperAwardIcon)
local PaperPortrait = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperPortrait)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local RankSlip = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankSlip)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local StickyNote = require(ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftReviewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewViewModel)

local e = React.createElement

export type ShiftReviewPanelProps = {
	view: ShiftReviewViewModel.ReviewView,
	layout: UIPaperConstants.Layout,
	-- The folder's scale on this screen (ShiftReviewViewModel.fit).
	scale: number,
	onVote: (choice: ShiftTypes.Vote) -> (),
	-- The local player's company rank (RankViewModel.slip); absent until the server publishes it.
	rank: RankViewModel.SlipView?,
}

type Nodes = { [string]: React.ReactNode }

local COLOR = UIPaperConstants.COLOR
-- Figma 5a/5b scrim: near-black at 80% over the office.
local SCRIM_TRANSPARENCY = 0.2
-- The desktop folder (Figma 5a): 1600x900 under the 46 px tab; the phone folder (5b) fills the safe area.
local DESKTOP_TAB = 46
local DESKTOP = Vector2.new(1600, 900)
local PHONE = Vector2.new(748, 358)
-- Desktop sticky-note grid (340 wide), alternate tilts; phone pair (176 wide).
local DESKTOP_STICKIES = { Vector2.new(848, 90), Vector2.new(1218, 90), Vector2.new(848, 280), Vector2.new(1218, 280) }
-- Phone notes start 20 px under the stat cards (cards end at y 206), so their tape clears them.
local PHONE_STICKIES = { Vector2.new(16, 226), Vector2.new(204, 226) }
-- A smaller strip of tape for the 176 px phone notes, so it clears the stat cards above them.
local PHONE_TAPE = Vector2.new(80, 18)
local DOT = 26
-- The folder tab (Figma 5a: 399 wide) and its label size. Roblox fits Oswald's tall line box into TextSize, so a
-- Figma size is drawn about 1.4x larger to match its glyphs (and >= 20 px on desktop).
local TAB_WIDTH = 399
local TAB_TEXT = 28
-- The QUOTA MET / MISSED hero stamp (Figma 5a/5c 395-499 px wide at fs64; 5b 177 px at fs22), sized to match.
local HEADLINE_DESKTOP = 96
-- The overall-rating stamp (Figma about 44 / 24), left-anchored after its label so the longest text (EXCEEDS
-- EXPECTATIONS, about 390 px wide at 44) grows to the right instead of over "Overall rating:".
local RATING_DESKTOP = 44
local RATING_PHONE = 24
local LEFT_CENTRE = Vector2.new(0, 0.5)
local HEADLINE_PHONE = 38
-- "your vote" in marker ink: above the legibility floors (desktop >= 20, phone >= 14) as drawn.
local MARK_DESKTOP = 28
local MARK_PHONE = 18
local DOT_STEP = 32
-- The rank slip (desktop: under the overall rating, Harlow's line moved down to QUOTE_WITH_RANK; phone: the right
-- column's foot).
local RANK_DESKTOP = Vector2.new(48, 640)
local QUOTE_DESKTOP = 700
local QUOTE_WITH_RANK = 790
local RANK_PHONE = Vector2.new(404, 330)

local function at(x: number, y: number): UDim2
	return UDim2.fromOffset(x, y)
end

local function label(
	text: string,
	role: PaperLabel.Role,
	size: number,
	x: number,
	y: number,
	width: number?
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		position = at(x, y),
		frame = if width ~= nil then UDim2.fromOffset(width, 0) else nil,
		fit = width == nil,
	})
end

local function rule(x: number, y: number, width: number, height: number): React.ReactNode
	return e("Frame", {
		Position = at(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = COLOR.companyTeal,
		BorderSizePixel = 0,
	})
end

local function stamp(text: string, size: number, tilt: number, x: number, y: number, anchor: Vector2?): React.ReactNode
	return e(PaperStamp, {
		text = text,
		size = size,
		tilt = tilt,
		anchor = anchor or Vector2.new(0.5, 0.5),
		position = at(x, y),
	})
end

local function portrait(userId: number): React.ReactNode
	return e(PaperPortrait, { userId = userId })
end

-- Dedicated award art; original SVG reviews share these exact 64 px shape definitions.
local function awardBadge(title: string): React.ReactNode
	return e(PaperAwardIcon, { title = title })
end

local function stickiesOf(
	awards: { ShiftReviewViewModel.AwardView },
	spots: { Vector2 },
	width: number,
	size: number,
	tape: Vector2?,
	into: Nodes
)
	for index, spot in spots do
		local award = awards[index]
		if award ~= nil then
			into[`award{index}`] = e(StickyNote, {
				text = `{award.title}\n{award.line}`,
				badge = if award.symbol ~= nil then awardBadge(award.title) else nil,
				badgeSize = if width < 200 then 24 else 40,
				portrait = if width >= 200 and award.userId ~= nil then portrait(award.userId) else nil,
				width = width,
				size = size,
				tape = tape,
				tilt = if index % 2 == 1 then -2 else 2,
				position = at(spot.X, spot.Y),
			})
		end
	end
end

-- A vote's dots (Figma 5a): `total` circles, the first `count` filled in ink, the rest outlined.
local function dotsOf(vote: ShiftReviewViewModel.VoteView, x: number, y: number): React.ReactNode
	local dots: Nodes = {}
	for index = 1, vote.total do
		local filled = index <= vote.count
		dots[`dot{index}`] = e("Frame", {
			Position = at((index - 1) * DOT_STEP, 0),
			Size = UDim2.fromOffset(DOT, DOT),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = if filled then 0 else 1,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", {
				Color = COLOR.ink,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
	end
	return e("Frame", {
		Position = at(x, y),
		Size = UDim2.fromOffset(vote.total * DOT_STEP, DOT),
		BackgroundTransparency = 1,
	}, dots)
end

local function desktopOf(props: ShiftReviewPanelProps): Nodes
	local view = props.view
	local nodes: Nodes = {
		companyStrip = e(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 7), BackgroundColor3 = COLOR.companyTeal, BorderSizePixel = 0 }
		),
		copyNumber = label("CC / RECEIPT • SHIFT CLEARANCE", "heading", 18, 48, 852, 650),
		subtitle = label(view.subtitle, "body", 22, 48, 30, 700),
		headline = stamp(view.headline, HEADLINE_DESKTOP, 2, 246, 140),
		ratingLabel = label(view.ratingLabel, "body", 24, 48, 590),
		rating = stamp(view.rating, RATING_DESKTOP, 2, 284, 604, LEFT_CENTRE),
		quote = label(
			`{view.quote}\n{view.quoteBy}`,
			"body",
			22,
			48,
			if props.rank ~= nil then QUOTE_WITH_RANK else QUOTE_DESKTOP,
			700
		),
		fold = rule(800, 30, 2, 840),
		awardsTitle = label("CREW CLOCKS OFF", "heading", 26, 848, 36),
		voteRule = rule(848, 500, 704, 2),
		voteTitle = label(view.voteTitle, "heading", 26, 848, 526),
		footer = label(view.footer, "body", 20, 848, 790, 704),
	}
	for index, row in view.rows do
		local y = 222 + (index - 1) * 84
		nodes[`rule{index}`] = rule(48, y, 700, 2)
		nodes[`label{index}`] = label(row.label, "heading", 24, 48, y + 16)
		nodes[`value{index}`] = e(PaperLabel, {
			text = row.value,
			role = "number",
			size = 52,
			align = "right",
			position = at(360, y + 6),
			frame = UDim2.fromOffset(388, 77),
			autoSize = false,
			wrapped = false,
		})
	end
	local rank = props.rank
	if rank ~= nil then
		nodes.rank = e(RankSlip, { view = rank, layout = "desktop", position = at(RANK_DESKTOP.X, RANK_DESKTOP.Y) })
	end
	stickiesOf(view.awards, DESKTOP_STICKIES, 340, 24, nil, nodes)
	local votes: { { key: string, vote: ShiftReviewViewModel.VoteView, choice: ShiftTypes.Vote, y: number } } = {
		{ key = "another", vote = view.another, choice = "another", y = 580 },
		{ key = "depot", vote = view.depot, choice = "depot", y = 680 },
	}
	for _, entry in votes do
		local vote = entry.vote
		nodes[entry.key] = e(PaperButton, {
			text = vote.label,
			variant = if entry.choice == "another" then "go" else "secondary",
			onPaper = true,
			disabled = not view.voteOpen,
			onActivated = function()
				props.onVote(entry.choice)
			end,
			position = at(848, entry.y),
			size = UDim2.fromOffset(286, 76),
			textSize = 30,
		})
		nodes[`{entry.key}Dots`] = dotsOf(vote, 1180, entry.y + 20)
		local mark = vote.mark
		if mark ~= nil then
			nodes[`{entry.key}Mark`] = e(PaperLabel, {
				text = mark,
				role = "marker",
				size = MARK_DESKTOP,
				anchor = Vector2.new(0, 0.5),
				position = at(1180 + vote.total * DOT_STEP + 14, entry.y + 34),
				fit = true,
			})
		end
	end
	return nodes
end

-- The phone's award toggle: a transparent 48 px tall touch target around "+2 MORE AWARDS".
local function toggleOf(text: string, onActivated: () -> ()): React.ReactNode
	return e(PaperButton, {
		text = text,
		variant = "surface",
		position = at(8, 339),
		anchor = Vector2.new(0, 0.5),
		size = UDim2.fromOffset(220, 48),
		textSize = 15,
		onActivated = onActivated,
	})
end

local function phoneOf(props: ShiftReviewPanelProps, expanded: boolean, toggle: () -> ()): Nodes
	local view = props.view
	local nodes: Nodes = {
		title = label(view.tab, "heading", 20, 16, 10),
		headline = stamp(view.headline, HEADLINE_PHONE, 3, 105, 70),
		voteTitle = label(view.voteTitle, "heading", 16, 404, 14),
		footer = label(view.footer, "body", 14, 404, 240, 320),
		ratingLabel = label(view.ratingLabel, "body", 15, 404, 306),
		rating = stamp(view.rating, RATING_PHONE, 2, 476, 315, LEFT_CENTRE),
	}
	for index, row in view.rows do
		local x = if index % 2 == 1 then 16 else 202
		local y = if index <= 2 then 100 else 156
		nodes[`row{index}`] = e("Frame", {
			Position = at(x, y),
			Size = UDim2.fromOffset(174, 50),
			BackgroundColor3 = COLOR.cream,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
		}, {
			label = label(row.label, "heading", 14, 10, 3),
			value = label(row.value, "number", 24, 10, 19),
		})
	end
	local rank = props.rank
	if rank ~= nil then
		nodes.rank = e(RankSlip, { view = rank, layout = "phone", position = at(RANK_PHONE.X, RANK_PHONE.Y) })
	end
	local more = view.moreAwards
	local less = view.lessAwards
	stickiesOf(if expanded then view.extraAwards else view.awards, PHONE_STICKIES, 176, 16, PHONE_TAPE, nodes)
	if more ~= nil and less ~= nil then
		nodes.toggle = toggleOf(if expanded then less else more, toggle)
	end
	local votes: { { key: string, vote: ShiftReviewViewModel.VoteView, choice: ShiftTypes.Vote, y: number } } = {
		{ key = "another", vote = view.another, choice = "another", y = 44 },
		{ key = "depot", vote = view.depot, choice = "depot", y = 144 },
	}
	for _, entry in votes do
		local vote = entry.vote
		nodes[entry.key] = e(PaperButton, {
			text = vote.text,
			variant = if entry.choice == "another" then "go" else "secondary",
			onPaper = true,
			disabled = not view.voteOpen,
			onActivated = function()
				props.onVote(entry.choice)
			end,
			position = at(404, entry.y),
			size = UDim2.fromOffset(280, 62),
			textSize = 20,
		})
		local mark = vote.mark
		if mark ~= nil then
			nodes[`{entry.key}Mark`] = label(mark, "marker", MARK_PHONE, 404, entry.y + 64)
		end
	end
	return nodes
end

local function ShiftReviewPanel(props: ShiftReviewPanelProps): React.ReactNode
	-- UI-only state: whether the phone shows its folded awards (hook called on every layout, for hook order).
	local expanded, setExpanded = React.useState(false)
	local phone = props.layout == "phone"
	local toggle = function()
		setExpanded(not expanded)
	end
	local sheet = if phone then PHONE else DESKTOP
	local top = if phone then 0 else DESKTOP_TAB
	local content = if phone then phoneOf(props, expanded, toggle) else desktopOf(props)

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.night,
		BackgroundTransparency = SCRIM_TRANSPARENCY,
		BorderSizePixel = 0,
		Active = true,
	}, {
		folder = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(sheet.X, sheet.Y + top),
			BackgroundTransparency = 1,
		}, {
			scale = e("UIScale", { Scale = props.scale }),
			sheet = e(PaperSheet, {
				position = at(0, top),
				size = UDim2.fromOffset(sheet.X, sheet.Y),
				tab = if phone then nil else props.view.tab,
				tabWidth = TAB_WIDTH,
				tabTextSize = TAB_TEXT,
				padding = 0,
				paper = COLOR.cream,
				fastener = "clip",
			}, content),
		}),
	})
end

return ShiftReviewPanel
