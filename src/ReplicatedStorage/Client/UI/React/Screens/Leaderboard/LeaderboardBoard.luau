--!strict
--[=[
	LeaderboardBoard: the hub's weekly crew board in the V1 kit at its 720x560 design size, drawn like the result board
	beside it (DepotResultBoard): a dark board plate under a grape title tab breaking its top edge, then a cream card
	(ToonPanel) with what the score means and when the board starts over, and one row per crew: its place as a stroked
	gold number, its names, its best Gloom as a stroked mint number. With no crews yet it says so. Presentational; the
	words are LeaderboardBoardViewModel.view.

	@class LeaderboardBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local LeaderboardBoardViewModel =
	require(ReplicatedStorage.Client.UI.React.Screens.Leaderboard.LeaderboardBoardViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)

local e = React.createElement

export type LeaderboardBoardProps = {
	view: LeaderboardBoardViewModel.View,
}

local BOARD = Vector2.new(720, 560)
local CARD = Vector2.new(640, 452)
local CARD_HEADER = 56
local ROW_TOP = CARD_HEADER + 12
local ROW_HEIGHT = 37

local function card(view: LeaderboardBoardViewModel.View): React.ReactNode
	local face: { [string]: React.ReactNode } = {}
	for index, row in view.rows do
		local y = ROW_TOP + (index - 1) * ROW_HEIGHT
		face[`rank{index}`] = e(ToonText, {
			text = row.rank,
			meaning = "gold",
			textSize = 28,
			position = UDim2.fromOffset(18, y),
			size = UDim2.fromOffset(44, ROW_HEIGHT - 4),
			align = "center",
			fit = true,
		})
		face[`names{index}`] = e(ToonText, {
			text = row.names,
			font = "body",
			textSize = 22,
			position = UDim2.fromOffset(72, y),
			size = UDim2.fromOffset(CARD.X - 72 - 150, ROW_HEIGHT - 4),
			fit = true,
		})
		face[`score{index}`] = e(ToonText, {
			text = row.score,
			meaning = "mint",
			textSize = 28,
			position = UDim2.fromOffset(CARD.X - 140, y),
			size = UDim2.fromOffset(120, ROW_HEIGHT - 4),
			align = "right",
			fit = true,
		})
	end
	local empty = view.empty
	if empty ~= nil then
		face.empty = e(ToonText, {
			text = empty,
			font = "body",
			textSize = 28,
			position = UDim2.fromOffset(32, ROW_TOP + 120),
			size = UDim2.fromOffset(CARD.X - 64, 90),
			align = "center",
			wrapped = true,
			fit = true,
		})
	end
	return e(ToonPanel, {
		position = UDim2.fromOffset(40, 84),
		size = CARD,
		header = { title = view.subtitle, height = CARD_HEADER, titleSize = 22 },
		children = face,
	})
end

local function LeaderboardBoard(props: LeaderboardBoardProps): React.ReactNode
	local view = props.view
	local tab: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = view.title,
			textSize = 34,
			position = UDim2.fromOffset(20, 0),
			size = UDim2.new(1, -40, 1, 0),
			align = "center",
			fit = true,
		}),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(BOARD.X, BOARD.Y),
		BackgroundTransparency = 1,
	}, {
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
			size = UDim2.fromOffset(460, 62),
			zIndex = 5,
			children = tab,
		}),
		card = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, { card = card(view) }),
	})
end

return LeaderboardBoard
