--!strict
--[=[
	ShiftReviewStatCard: one of the results screen's four stat cards (ShiftReviewPanel): its render breaking the card's
	left edge, the label and the big value; the Credits card is the gold one, with sparkles. Split out of
	ShiftReviewPanel, which places them 2x2. Presentational (exempt; story in ShiftReviewPanel.story; the cards are
	specced in ShiftReviewViewModel).

	@class ShiftReviewStatCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftReviewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonText = require(Toon.ToonText)

local e = React.createElement

type Nodes = { [string]: React.ReactNode }

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

return statCard
