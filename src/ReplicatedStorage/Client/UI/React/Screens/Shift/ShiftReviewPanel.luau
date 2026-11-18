--!strict
--[=[
	ShiftReviewPanel: the results screen in the V1 kit (results render; the user's favourite): over the darkened office,
	slow gold rays and a clean diagonal band (wiped clean by the squeegee as it opens) behind the huge stroked
	CONTRACT MET! (gold) or CONTRACT MISSED (coral), the grade medallion breaking the title, Gleam sparkles (art); the
	"SHIFT REVIEW · <client>" pill (view.pill); four stat cards whose renders break their left edge (the Credits card is the
	gold one); the company rank (RankSlip) under them with the Manager's line and the vote's footer; CREW AWARDS on
	the right, the first award featured on a gold card with its winner's own character standing on its corner; and
	the crew vote: the mint ANOTHER SHIFT and the cream TO THE DEPOT with their counts (a Night Shift's NEXT: NIGHT n
	and CLOCK OUT; once its run is over the next night is off and a coral or gold pill on the tab's spot says how it
	ended and the night reached, under the run-over title), the local player's choice in V2's lilac selected ring,
	the time left on a coral pill. Laid out at 1680x900 design px (phone 760x370,
	ShiftReviewViewModel.CANVAS) and scaled by `scale` (ShiftReviewViewModel.fit), centred. On the phone "+2 MORE
	AWARDS" swaps in the folded awards (UI-only state); "WHAT NEXT?", the vote clock and that button share one row
	above the vote, clear of the chosen button's lifted ring. Pills are sized from their measured labels
	(ToonStyleViewModel.pillWidth; the rating badge by ShiftReviewViewModel.badge), so no label is cut.
	Presentational: it draws the view it is given (specced in ShiftReviewViewModel and RankViewModel). The stat cards
	and the award cards are ShiftReviewStatCard and ShiftReviewAwardCard.

	@class ShiftReviewPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local React = require(ReplicatedStorage.Packages.React)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local RankSlip = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankSlip)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local ShiftReviewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewViewModel)
local awardCard = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewAwardCard)
local statCard = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewStatCard)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonPill = require(Toon.ToonPill)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonWipe = require(Toon.ToonWipe)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type ShiftReviewPanelProps = {
	view: ShiftReviewViewModel.ReviewView,
	layout: UIPaperConstants.Layout,
	-- The layout's scale on this screen (ShiftReviewViewModel.fit).
	scale: number,
	onVote: (choice: ShiftTypes.Vote) -> (),
	-- The local player's company rank (RankViewModel.slip); absent until the server publishes it.
	rank: RankViewModel.SlipView?,
	-- What the shift paid in a live event's acorns ("+40 acorns", ShiftReviewViewModel.acornsText); nil hides the tag.
	acorns: string?,
}

type Nodes = { [string]: React.ReactNode }

-- One turn of the rays, in seconds.
local RAYS_PERIOD = 60

-- The width (design px) a pill needs for its Luckiest Guy `text` at `textSize` with `padX` side padding.
local function pillFor(text: string, textSize: number, padX: number): number
	local width = TextService:GetTextSize(text, textSize, Enum.Font.LuckiestGuy, Vector2.new(10000, 1000)).X
	return ToonStyleViewModel.pillWidth(width, textSize, padX)
end

local function voteButton(
	vote: ShiftReviewViewModel.VoteView,
	choice: ShiftTypes.Vote,
	open: boolean,
	phone: boolean,
	position: UDim2,
	width: number,
	onVote: (choice: ShiftTypes.Vote) -> ()
): React.ReactNode
	local height = if phone then 44 else 84
	local count = if phone then 30 else 54
	local content: Nodes = {
		label = e(ToonText, {
			text = vote.button,
			textSize = if phone then 20 else 38,
			position = UDim2.fromOffset(if phone then 10 else 22, 0),
			size = UDim2.new(1, -(count + (if phone then 22 else 44)), 1, -4),
			align = "center",
			fit = true,
		}),
		count = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, if phone then -8 else -16, 0.5, -2),
			Size = UDim2.fromOffset(count, count),
			BackgroundColor3 = COLOR.ink,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			number = e(ToonText, {
				text = tostring(vote.count),
				textSize = if phone then 18 else 28,
				size = UDim2.fromScale(1, 1),
				align = "center",
			}),
		}),
	}
	return e(ToonButton, {
		variant = if choice == "another" then "primary" else "secondary",
		size = UDim2.fromOffset(width, height),
		position = position,
		selected = vote.mine,
		disabled = not open or vote.disabled,
		content = content,
		sound = if choice == "another" then "cta" else "back",
		onActivated = function()
			onVote(choice)
		end,
	})
end

local function headline(view: ShiftReviewViewModel.ReviewView, phone: boolean, canvas: Vector2): Nodes
	local titleSize = if phone then 60 else 150
	local centreY = if phone then 46 else 180
	local ratingSize = if phone then 12 else 20
	local badge = ShiftReviewViewModel.badge(pillFor(view.rating, ratingSize, if phone then 8 else 12), phone)
	local spin = useToonPlay(RAYS_PERIOD, 0, nil, true)
	local medal: Nodes = {}
	medal.grade = e(ToonText, {
		text = view.grade,
		textSize = if phone then 52 else 124,
		size = UDim2.fromScale(1, 0.9),
		align = "center",
	})
	local band: Nodes = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, if phone then 20 else 40) }),
		wipe = e(ToonWipe, { radius = if phone then 20 else 40, delay = 0.25 }),
	}
	return {
		rays = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(canvas.X / 2, centreY),
			Size = UDim2.fromOffset(if phone then 700 else 1600, if phone then 700 else 1600),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.rays,
			ImageColor3 = if view.met then UIToonConstants.shade("gold").hi else UIToonConstants.shade("lilac").hi,
			ImageTransparency = 0.82,
			Rotation = spin:map(function(alpha: number): number
				return alpha * 360
			end),
			ZIndex = 0,
		}),
		band = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(canvas.X / 2, centreY + 6),
			Size = UDim2.fromOffset(if phone then 600 else 1320, if phone then 80 else 196),
			Rotation = -3,
			BackgroundColor3 = COLOR.white,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, band),
		title = e(ToonText, {
			text = view.title,
			meaning = if view.met then "gold" else "coral",
			textSize = titleSize,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(canvas.X / 2 - (if phone then 30 else 60), centreY),
			size = UDim2.fromOffset(if phone then 560 else 1240, titleSize + 20),
			align = "center",
			rotation = -3,
			fit = true,
			zIndex = 3,
		}),
		medal = e(ToonSurface, {
			hue = if view.met then "mint" else "coral",
			radius = 999,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(badge.medalX, centreY - (if phone then 4 else 20)),
			size = UDim2.fromOffset(if phone then 84 else 196, if phone then 84 else 196),
			zIndex = 4,
			children = medal,
		}),
		rating = e(ToonPill, {
			text = view.rating,
			hue = "night",
			textSize = ratingSize,
			padX = if phone then 8 else nil,
			tilt = 8,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(badge.x, centreY + (if phone then 38 else 84)),
			size = UDim2.fromOffset(badge.width, if phone then 22 else 38),
			zIndex = 5,
		}),
		sparkles = e(ToonSparkle, {
			spots = {
				{
					position = UDim2.fromOffset(canvas.X * 0.24, centreY - titleSize * 0.42),
					size = if phone then 26 else 58,
				},
				{
					position = UDim2.fromOffset(canvas.X * 0.69, centreY - titleSize * 0.55),
					size = if phone then 22 else 46,
				},
				{
					position = UDim2.fromOffset(canvas.X * 0.32, centreY + titleSize * 0.55),
					size = if phone then 16 else 34,
				},
				{
					position = UDim2.fromOffset(canvas.X * 0.77, centreY + titleSize * 0.5),
					size = if phone then 18 else 38,
				},
			},
			zIndex = 6,
		}),
	}
end

local function ShiftReviewPanel(props: ShiftReviewPanelProps): React.ReactNode
	local view = props.view
	local phone = props.layout == "phone"
	local canvas = if phone then ShiftReviewViewModel.CANVAS.phone else ShiftReviewViewModel.CANVAS.desktop
	local showExtra, setShowExtra = React.useState(false)
	-- The text fit limits follow the scale the canvas is drawn at (PaperScaleContext).
	local outer = React.useContext(PaperScaleContext.Context)
	local deps: { unknown } = { outer, props.scale }
	local combined = React.useMemo(function(): React.Binding<number>
		return outer:map(function(value: number): number
			return value * props.scale
		end)
	end, deps)
	local nodes: Nodes = headline(view, phone, canvas)
	local ended = view.ended or view.report
	if ended ~= nil then
		-- A Night Shift run that is over (how it ended and the night reached) or a survived week's report (the nights
		-- survived and the bonus), on the tab's spot (and over the phone's title), coral for a bad ending, gold for a
		-- clock-out or a week done.
		nodes.tab = e(ToonPill, {
			text = ended.line,
			hue = if ended.good then "gold" else "coral",
			textSize = if phone then 14 else 26,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.fromOffset(canvas.X / 2, if phone then -8 else 0),
			size = UDim2.fromOffset(if phone then 440 else 820, if phone then 24 else 52),
			zIndex = 4,
		})
	elseif not phone then
		nodes.tab = e(ToonPill, {
			text = view.pill,
			hue = "night",
			textSize = 26,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.fromOffset(canvas.X / 2, 0),
			size = UDim2.fromOffset(540, 52),
			zIndex = 4,
		})
	end
	-- The stat cards, 2x2 on the left.
	local cardsTop = if phone then 96 else 300
	local cardW = if phone then 188 else 420
	local cardH = if phone then 82 else 154
	for index, card in view.cards do
		local column = (index - 1) % 2
		local row = (index - 1) // 2
		nodes[`card{index}`] =
			statCard(card, phone, UDim2.fromOffset((if phone then 20 else 30) + column * cardW, cardsTop + row * cardH))
	end
	-- The acorns a live event paid: a tag on the Credits card's top-right corner (where the Shop's corner flags sit).
	local acorns = props.acorns
	if acorns ~= nil then
		local creditsRight = (if phone then 20 else 30) + 2 * cardW
		nodes.acorns = e(ToonPill, {
			text = acorns,
			hue = "coral",
			meaning = "gold",
			icon = "acorns",
			textSize = if phone then 13 else 24,
			tilt = 4,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.fromOffset(creditsRight - (if phone then 6 else 14), cardsTop + 2),
			size = UDim2.fromOffset(if phone then 104 else 210, if phone then 24 else 44),
			zIndex = 6,
		})
	end
	local rank = props.rank
	if rank ~= nil then
		nodes.rank = e(RankSlip, {
			view = rank,
			layout = props.layout,
			position = UDim2.fromOffset(if phone then 20 else 30, cardsTop + 2 * cardH + (if phone then 4 else 10)),
		})
	end
	if not phone then
		nodes.quote = e(ToonText, {
			text = `{view.quote}  {view.quoteBy}`,
			font = "body",
			color = COLOR.white,
			textSize = 22,
			position = UDim2.fromOffset(30, 780),
			size = UDim2.fromOffset(820, 30),
			fit = true,
		})
		nodes.footer = e(ToonText, {
			text = view.footer,
			font = "body",
			color = UIToonConstants.shade("lilac").hi,
			textSize = 18,
			position = UDim2.fromOffset(30, 818),
			size = UDim2.fromOffset(820, 26),
			fit = true,
		})
	end
	-- The awards on the right.
	local right = if phone then 400 else 900
	local width = canvas.X - right
	nodes.awardsTitle = e(ToonText, {
		text = "CREW AWARDS",
		textSize = if phone then 22 else 44,
		position = UDim2.fromOffset(right, if phone then 92 else 286),
		size = UDim2.fromOffset(width, if phone then 26 else 50),
	})
	local awards: { ShiftReviewViewModel.AwardView } = if phone and showExtra then view.extraAwards else view.awards
	local y = if phone then 124 else 350
	-- The last card's bottom edge: the desktop vote row sits under it (ShiftReviewViewModel.voteRow).
	local awardsBottom = y
	for index, award in awards do
		local featured = index == 1 and not (phone and showExtra)
		nodes[`award{index}`] = awardCard(award, featured, phone, width, UDim2.fromOffset(right, y), view.grade)
		awardsBottom = y + (if featured then (if phone then 72 else 148) else (if phone then 54 else 78))
		y = awardsBottom + (if phone then 8 else 12)
	end
	local more, less = view.moreAwards, view.lessAwards
	if phone and more ~= nil then
		-- Under the awards, right-aligned, clear of the vote below; as wide as its longer label (12 px label inset).
		nodes.more = e(ToonButton, {
			variant = "lilac",
			small = true,
			text = if showExtra then less else more,
			textSize = 13,
			anchor = Vector2.new(1, 0),
			position = UDim2.fromOffset(canvas.X, y - 2),
			size = UDim2.fromOffset(math.max(pillFor(more, 13, 12), pillFor(less or more, 13, 12)), 24),
			onActivated = function()
				setShowExtra(function(open: boolean)
					return not open
				end)
			end,
		})
	end
	-- The crew vote, bottom right; on desktop clear of the awards' ink; on phone high enough that the chosen button's
	-- lilac ring and its drop stay on the screen, its header row 52 px up (the chosen button's ring reaches 20 px over
	-- it), the clock right after the measured "WHAT NEXT?".
	local voteRow = ShiftReviewViewModel.voteRow(awardsBottom, phone)
	local headerTop = voteRow.headerTop
	nodes.voteTitle = e(ToonText, {
		text = if view.voting then "WHAT NEXT?" else view.voteTitle,
		textSize = if phone then 18 else 40,
		position = UDim2.fromOffset(right, headerTop),
		size = UDim2.fromOffset(if phone then 120 else 260, if phone then 22 else 44),
		fit = true,
	})
	local clockWidth = if phone then math.max(92, pillFor(`VOTE · {view.voteClock}`, 12, 8)) else 160
	local clockAt = UDim2.fromOffset(
		right + (if phone then pillFor("WHAT NEXT?", 18, 0) + 2 else 270),
		headerTop + (if phone then ShiftReviewViewModel.PHONE_CLOCK.top else 4)
	)
	nodes.voteClock = e(ToonPill, {
		text = if view.voting then `VOTE · {view.voteClock}` else `HOME · {view.voteClock}`,
		hue = "coral",
		textSize = if phone then 12 else 20,
		padX = if phone then 8 else nil,
		position = clockAt,
		size = UDim2.fromOffset(clockWidth, if phone then ShiftReviewViewModel.PHONE_CLOCK.height else 36),
	})
	local gap = if phone then 10 else 20
	local half = (width - gap) / 2
	-- A Night Shift run that is over takes no vote: the header and the clock home stand alone.
	for index = 1, if view.voting then 2 else 0 do
		local choice: ShiftTypes.Vote = if index == 1 then "another" else "depot"
		local vote = if index == 1 then view.another else view.depot
		local at = UDim2.fromOffset(right + (index - 1) * (half + gap), voteRow.buttonsTop)
		nodes[choice] = voteButton(vote, choice, view.voteOpen, phone, at, half, props.onVote)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.ink,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}, {
		vignette = e("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(UIToonConstants.shade("night").base, COLOR.ink),
		}),
		canvas = e(PaperScaleContext.Context.Provider, { value = combined }, {
			frame = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(canvas.X, canvas.Y),
				BackgroundTransparency = 1,
			}, {
				scale = e("UIScale", { Scale = props.scale }),
				content = e(React.Fragment, nil, nodes),
			}),
		}),
	})
end

return ShiftReviewPanel
