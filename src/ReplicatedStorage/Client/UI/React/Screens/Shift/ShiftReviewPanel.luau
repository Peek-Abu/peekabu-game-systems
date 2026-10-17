--!strict
--[=[
	ShiftReviewPanel: the results screen in the V1 kit (results render; the user's favourite): over the darkened office,
	slow gold rays and a clean diagonal band (wiped clean by the squeegee as it opens) behind the huge stroked
	CONTRACT MET! (gold) or CONTRACT MISSED (coral), the grade medallion breaking the title, Gleam sparkles; the
	"SHIFT REVIEW · HARLOW & FINCH" pill; four stat cards whose renders break their left edge (the Gleam card is the
	gold one); the company rank (RankSlip) under them with the Manager's line and the vote's footer; CREW AWARDS on
	the right, the first award featured on a gold card with Pippa saluting from its corner; and the crew vote: the mint
	ANOTHER SHIFT and the cream TO THE DEPOT with their counts, the local player's choice in V2's lilac selected ring,
	the time left on a coral pill. Laid out at 1680x900 design px (phone 760x370) and scaled by `scale`
	(ShiftReviewViewModel.fit), centred. On the phone "+2 MORE AWARDS" swaps in the folded awards (UI-only state).
	Presentational: it draws the view it is given (specced in ShiftReviewViewModel and RankViewModel).

	@class ShiftReviewPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local RankSlip = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankSlip)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)
local ShiftReviewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonSparkle = require(Toon.ToonSparkle)
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
}

type Nodes = { [string]: React.ReactNode }

-- The design canvases (desktop / phone) the layout is drawn in before `scale`.
local DESKTOP = Vector2.new(1680, 900)
local PHONE = Vector2.new(760, 370)
-- One turn of the rays, in seconds.
local RAYS_PERIOD = 60

local function statCard(card: ShiftReviewViewModel.CardView, phone: boolean, position: UDim2): React.ReactNode
	local size = if phone then Vector2.new(180, 74) else Vector2.new(400, 132)
	local icon = if phone then 70 else 136
	local left = if phone then 50 else 116
	local face: Nodes = {
		icon = e(ToonIcon, {
			icon = card.icon,
			position = UDim2.fromOffset(-icon * 0.3, (size.Y - icon) / 2 - 4),
			size = UDim2.fromOffset(icon, icon),
			drop = if phone then 3 else 6,
			zIndex = 5,
		}),
		label = e(ToonText, {
			text = card.label,
			font = "body",
			textSize = if phone then 13 else 22,
			position = UDim2.fromOffset(left, if phone then 4 else 16),
			size = UDim2.fromOffset(size.X - left - 10, if phone then 16 else 28),
			fit = true,
		}),
		value = e(ToonText, {
			text = card.value,
			meaning = card.meaning,
			textSize = if phone then 30 else 62,
			position = UDim2.fromOffset(left, if phone then 24 else 48),
			size = UDim2.fromOffset(size.X - left - 12, if phone then 38 else 70),
			fit = true,
		}),
	}
	if card.gold then
		face.sparkles = e(ToonSparkle, {
			spots = {
				{ position = UDim2.new(1, -24, 0, 6), size = if phone then 16 else 30 },
				{ position = UDim2.new(1, -60, 1, -14), size = if phone then 12 else 22 },
			},
			zIndex = 6,
		})
	end
	return e(ToonPanel, {
		hue = if card.gold then "gold" else "cream",
		size = size,
		position = position,
		radius = if phone then 18 else 26,
		children = face,
	})
end

local function awardCard(
	award: ShiftReviewViewModel.AwardView,
	featured: boolean,
	phone: boolean,
	width: number,
	position: UDim2
): React.ReactNode
	local height = if featured then (if phone then 72 else 148) else (if phone then 54 else 78)
	local icon = if featured then (if phone then 70 else 128) else (if phone then 50 else 84)
	local left = if phone then icon * 0.62 else icon * 0.72
	local face: Nodes = {
		title = e(ToonText, {
			text = award.title,
			textSize = if featured then (if phone then 20 else 42) else (if phone then 15 else 28),
			position = UDim2.fromOffset(left, if featured then (if phone then 6 else 30) else 4),
			size = UDim2.fromOffset(
				width - left - (if featured then 200 else 20),
				if featured then (if phone then 24 else 48) else (if phone then 20 else 34)
			),
			fit = true,
		}),
		line = e(ToonText, {
			text = award.line,
			font = "body",
			textSize = if phone then 13 else 22,
			position = UDim2.fromOffset(
				left + 2,
				if featured then (if phone then 36 else 84) else (if phone then 28 else 42)
			),
			size = UDim2.fromOffset(width - left - (if featured then 200 else 20), if phone then 16 else 28),
			fit = true,
		}),
	}
	if award.icon ~= nil then
		face.icon = e(ToonIcon, {
			icon = award.icon,
			position = UDim2.fromOffset(-icon * 0.3, (height - icon) / 2 - 4),
			size = UDim2.fromOffset(icon, icon),
			drop = 5,
			zIndex = 5,
		})
	end
	if featured then
		face.pippa = e(ToonIcon, {
			image = UIAssets.toonPhotos.pippaSaluteCut,
			anchor = Vector2.new(1, 1),
			position = UDim2.new(1, if phone then 6 else 10, 1, 4),
			size = UDim2.fromOffset(if phone then 90 else 200, if phone then 104 else 230),
			drop = 0,
			zIndex = 6,
		})
	end
	return e(ToonPanel, {
		hue = if featured then "gold" else "cream",
		size = Vector2.new(width, height),
		position = position,
		radius = if phone then 18 else 26,
		children = face,
	})
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
	local height = if phone then 54 else 84
	local count = if phone then 34 else 54
	local content: Nodes = {
		label = e(ToonText, {
			text = if choice == "depot" then "TO THE DEPOT" else vote.label,
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
		disabled = not open,
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
			position = UDim2.fromOffset(canvas.X - (if phone then 50 else 150), centreY - (if phone then 4 else 20)),
			size = UDim2.fromOffset(if phone then 84 else 196, if phone then 84 else 196),
			zIndex = 4,
			children = medal,
		}),
		rating = e(ToonPill, {
			text = view.rating,
			hue = "night",
			textSize = if phone then 11 else 20,
			tilt = 8,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(canvas.X - (if phone then 50 else 150), centreY + (if phone then 38 else 84)),
			size = UDim2.fromOffset(if phone then 110 else 260, if phone then 22 else 38),
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
	local canvas = if phone then PHONE else DESKTOP
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
	if not phone then
		nodes.tab = e(ToonPill, {
			text = "SHIFT REVIEW · HARLOW & FINCH",
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
	for index, award in awards do
		local featured = index == 1 and not (phone and showExtra)
		nodes[`award{index}`] = awardCard(award, featured, phone, width, UDim2.fromOffset(right, y))
		y += (if featured then (if phone then 72 else 148) else (if phone then 54 else 78)) + (if phone then 8 else 12)
	end
	if phone and view.moreAwards ~= nil then
		nodes.more = e(ToonButton, {
			variant = "lilac",
			small = true,
			text = if showExtra then view.lessAwards else view.moreAwards,
			textSize = 13,
			position = UDim2.fromOffset(right, y),
			size = UDim2.fromOffset(170, 30),
			onActivated = function()
				setShowExtra(function(open: boolean)
					return not open
				end)
			end,
		})
	end
	-- The crew vote, bottom right.
	local voteTop = if phone then 312 else 770
	nodes.voteTitle = e(ToonText, {
		text = "WHAT NEXT?",
		textSize = if phone then 18 else 40,
		position = UDim2.fromOffset(right, voteTop - (if phone then 26 else 6)),
		size = UDim2.fromOffset(if phone then 120 else 260, if phone then 22 else 44),
		fit = true,
	})
	nodes.voteClock = e(ToonPill, {
		text = `VOTE · {view.voteClock}`,
		hue = "coral",
		textSize = if phone then 12 else 20,
		position = UDim2.fromOffset(right + (if phone then 126 else 270), voteTop - (if phone then 26 else 2)),
		size = UDim2.fromOffset(if phone then 92 else 160, if phone then 22 else 36),
	})
	local half = (width - (if phone then 10 else 20)) / 2
	local buttonTop = voteTop + (if phone then 0 else 46)
	nodes.another = voteButton(
		view.another,
		"another",
		view.voteOpen,
		phone,
		UDim2.fromOffset(right, buttonTop),
		half,
		props.onVote
	)
	nodes.depot = voteButton(
		view.depot,
		"depot",
		view.voteOpen,
		phone,
		UDim2.fromOffset(right + half + (if phone then 10 else 20), buttonTop),
		half,
		props.onVote
	)
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
