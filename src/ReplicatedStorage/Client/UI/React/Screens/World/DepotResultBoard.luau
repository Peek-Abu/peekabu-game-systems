--!strict
--[=[
	DepotResultBoard: the result board in the V1 kit at its 1140x446 design size: a dark board plate on the depth stack
	(night, goo bubbles) under a grape title tab breaking its top edge. With `review` (your card): a cream card on the
	stack, its grape header band naming the shift, the four rows (labels in Fredoka, values as stroked gold numbers),
	CONTRACT MET / MISSED as a big stroked mint or coral title with the rating on a gold pill, the crew line and
	Harlow's quote; and one gold award card per award (the award's render breaking its corner, the title over the
	name), tilted on the board's right. Without it: the bare board. Presentational; the words are
	DepotWorldViewModel.review.

	@class DepotResultBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local ShiftReviewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type DepotResultBoardProps = {
	title: string,
	review: DepotWorldViewModel.ReviewView?,
}

local BOARD = Vector2.new(1140, 446)
local AWARD_AT: { Vector2 } = { Vector2.new(690, 96), Vector2.new(912, 112), Vector2.new(800, 262) }
local AWARD_TILT: { number } = { 3, -3, 1 }
local AWARD = Vector2.new(196, 112)
local CARD = Vector2.new(586, 336)
local CARD_HEADER = 60
local ROW_HEIGHT = 42

local function reviewCard(review: DepotWorldViewModel.ReviewView): React.ReactNode
	local face: { [string]: React.ReactNode } = {}
	local top = CARD_HEADER + 14
	for index, row in review.rows do
		local y = top + (index - 1) * ROW_HEIGHT
		face[`label{index}`] = e(ToonText, {
			text = row.label,
			font = "body",
			textSize = 20,
			position = UDim2.fromOffset(24, y),
			size = UDim2.fromOffset(150, ROW_HEIGHT - 6),
			fit = true,
		})
		face[`value{index}`] = e(ToonText, {
			text = row.value,
			meaning = "gold",
			textSize = 30,
			position = UDim2.fromOffset(176, y),
			size = UDim2.fromOffset(150, ROW_HEIGHT - 4),
			fit = true,
		})
		face[`rule{index}`] = e("Frame", {
			Position = UDim2.fromOffset(24, y + ROW_HEIGHT - 4),
			Size = UDim2.fromOffset(304, 2),
			BackgroundColor3 = UIToonConstants.shade("cream").lo,
			BorderSizePixel = 0,
		})
	end
	face.headline = e(ToonText, {
		text = review.headline,
		meaning = if review.met then "mint" else "coral",
		textSize = 40,
		rotation = -4,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromOffset(456, top + 44),
		size = UDim2.fromOffset(230, 92),
		align = "center",
		wrapped = true,
		fit = true,
	})
	face.rating = e(ToonPill, {
		text = review.rating,
		hue = "gold",
		textSize = 18,
		tilt = 2,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromOffset(456, top + 116),
		size = UDim2.fromOffset(210, 38),
	})
	face.crew = e(ToonText, {
		text = review.crew,
		font = "body",
		textSize = 18,
		position = UDim2.fromOffset(24, top + 4 * ROW_HEIGHT + 8),
		size = UDim2.new(1, -48, 0, 24),
		fit = true,
	})
	face.quote = e(ToonText, {
		text = review.quote,
		font = "body",
		textSize = 16,
		color = UIToonConstants.shade("grape").lo,
		position = UDim2.fromOffset(24, top + 4 * ROW_HEIGHT + 36),
		size = UDim2.new(1, -48, 0, 44),
		wrapped = true,
		fit = true,
		alignY = "top",
	})
	return e(ToonPanel, {
		position = UDim2.fromOffset(52, 76),
		size = CARD,
		header = { title = review.band, height = CARD_HEADER, titleSize = 30 },
		children = face,
	})
end

local function awardCard(sticky: DepotWorldViewModel.StickyView, index: number, at: Vector2): React.ReactNode
	local symbol: ShiftReviewViewModel.AwardSymbol? = ShiftReviewViewModel.awardSymbol(sticky.title)
	local face: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = sticky.title,
			textSize = 20,
			position = UDim2.fromOffset(52, 12),
			size = UDim2.new(1, -64, 0, 28),
			fit = true,
		}),
		name = e(ToonText, {
			text = sticky.name,
			font = "body",
			textSize = 18,
			position = UDim2.fromOffset(16, 52),
			size = UDim2.new(1, -32, 0, 40),
			wrapped = true,
			fit = true,
			alignY = "top",
		}),
	}
	return e("Frame", {
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(AWARD.X, AWARD.Y),
		Rotation = AWARD_TILT[index] or 0,
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, {
		card = e(ToonSurface, {
			hue = "gold",
			radius = 20,
			size = UDim2.new(1, 0, 1, -7),
			children = face,
		}),
		icon = e(ToonIcon, {
			icon = if symbol ~= nil then ShiftReviewViewModel.awardIcon(symbol) else "trophy",
			position = UDim2.fromOffset(-16, -22),
			size = UDim2.fromOffset(64, 64),
			rotation = -8,
			drop = 4,
			zIndex = 5,
		}),
	})
end

local function DepotResultBoard(props: DepotResultBoardProps): React.ReactNode
	local tab: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = props.title,
			textSize = 34,
			position = UDim2.fromOffset(20, 0),
			size = UDim2.new(1, -40, 1, 0),
			align = "center",
			fit = true,
		}),
	}
	local children: { [string]: React.ReactNode } = {
		board = e(ToonPanel, {
			hue = "night",
			gloss = false,
			position = UDim2.fromOffset(12, 30),
			size = Vector2.new(BOARD.X - 24, BOARD.Y - 42),
		}),
		tab = e(ToonSurface, {
			hue = "grape",
			radius = 22,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 4),
			size = UDim2.fromOffset(420, 62),
			zIndex = 5,
			children = tab,
		}),
	}
	local review = props.review
	if review ~= nil then
		children.card = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, { card = reviewCard(review) })
		for index, sticky in review.stickies do
			local at: Vector2? = AWARD_AT[index]
			if at ~= nil then
				children[`award{index}`] = awardCard(sticky, index, at)
			end
		end
	end
	return e("Frame", {
		Size = UDim2.fromOffset(BOARD.X, BOARD.Y),
		BackgroundTransparency = 1,
	}, children)
end

return DepotResultBoard
