--!strict
--[=[
	ShiftReviewAwardCard: one crew award on the results screen (ShiftReviewPanel): its icon breaking the card's left
	edge, the title and the line; the featured (first) award is a bigger gold card with its winner's own character,
	posed for the shift's grade, standing on its corner (Pippa cheering when the winner is unknown). Split out of
	ShiftReviewPanel, which stacks them. Presentational (exempt; story in ShiftReviewPanel.story; the awards are
	specced in ShiftReviewViewModel).

	@class ShiftReviewAwardCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local CharacterPortrait = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.CharacterPortrait)
local ShiftReviewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftReviewViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonText = require(Toon.ToonText)

local e = React.createElement

type Nodes = { [string]: React.ReactNode }

local function awardCard(
	award: ShiftReviewViewModel.AwardView,
	featured: boolean,
	phone: boolean,
	width: number,
	position: UDim2,
	grade: string?
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
				width - left - (if featured then (if phone then 96 else 200) else 20),
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
			size = UDim2.fromOffset(
				width - left - (if featured then (if phone then 96 else 200) else 20),
				if phone then 16 else 28
			),
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
	if featured and award.userId ~= nil then
		-- The winner's own character, full figure, posed for the shift's grade, standing on the card's corner.
		face.pippa = e(CharacterPortrait, {
			userId = award.userId,
			context = "award",
			framing = "full",
			grade = grade,
			anchor = Vector2.new(1, 1),
			position = UDim2.new(1, if phone then 6 else 10, 1, 4),
			size = UDim2.fromOffset(if phone then 90 else 200, if phone then 104 else 230),
			zIndex = 6,
		})
	elseif featured then
		face.pippa = e(ToonIcon, {
			image = UIAssets.toonPhotos.pippaCheerCut,
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

return awardCard
