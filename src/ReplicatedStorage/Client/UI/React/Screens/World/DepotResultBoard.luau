--!strict
--[=[
	DepotResultBoard: the result board (Figma World UI 2a, W3 + W4) at its 1140x446 design size: a cork board
	(1140x420 at y 26, 20 px wood frame) under a 380x64 manilaDeep folder tab at (380, 0) with the title (Oswald 36).
	With `review` (your card, W4): the review card pinned at (60, 76), 568x330 cream, tilted -1.5° under an ink band,
	with the four rows, the QUOTA MET / MISSED stamp and the rating stamp, the crew line and Harlow's quote; and one
	sticky per award ("TITLE" over the name) at (675, 96), (900, 110) and (790, 262). Without it: the bare board.
	Presentational; the words are DepotWorldViewModel.review.

	@class DepotResultBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CorkBoard = require(ReplicatedStorage.Client.UI.React.Screens.Paper.CorkBoard)
local PaperAwardIcon = require(script.Parent.Parent.Paper.PaperAwardIcon)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local StickyNote = require(ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)

local e = React.createElement

export type DepotResultBoardProps = {
	title: string,
	review: DepotWorldViewModel.ReviewView?,
}

local COLOR = UIPaperConstants.COLOR
local STICKY_AT: { Vector2 } = { Vector2.new(675, 96), Vector2.new(900, 110), Vector2.new(790, 262) }
local STICKY_TILT: { number } = { 3, -3, 1 }
local ROW_HEIGHT = 42

local function badge(title: string): React.ReactNode
	return e(PaperAwardIcon, { title = title })
end

local function reviewCard(review: DepotWorldViewModel.ReviewView): React.ReactNode
	local content: { [string]: React.ReactNode } = {}
	for index, row in review.rows do
		local y = (index - 1) * ROW_HEIGHT
		content[`label{index}`] = e(PaperLabel, {
			text = row.label,
			role = "medium",
			size = 20,
			color = COLOR.ink,
			position = UDim2.fromOffset(0, y + 8),
			frame = UDim2.fromOffset(180, 30),
			autoSize = false,
			wrapped = false,
		})
		content[`value{index}`] = e(PaperLabel, {
			text = row.value,
			role = "number",
			size = 30,
			color = COLOR.ink,
			position = UDim2.fromOffset(180, y),
			frame = UDim2.fromOffset(130, 40),
			autoSize = false,
			wrapped = false,
			scaled = true,
		})
		content[`rule{index}`] = e("Frame", {
			Position = UDim2.fromOffset(0, y + ROW_HEIGHT - 2),
			Size = UDim2.fromOffset(310, 1),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
		})
	end
	content.headline = e(PaperStamp, {
		text = review.headline,
		size = 44,
		tilt = 4,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromOffset(420, 58),
	})
	content.rating = e(PaperStamp, {
		text = review.rating,
		size = 20,
		tilt = 2,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromOffset(420, 140),
	})
	content.crew = e(PaperLabel, {
		text = review.crew,
		role = "body",
		size = 18,
		color = COLOR.ink,
		position = UDim2.fromOffset(0, 186),
		frame = UDim2.new(1, 0, 0, 24),
		autoSize = false,
		wrapped = false,
		scaled = true,
	})
	content.quote = e(PaperLabel, {
		text = review.quote,
		role = "body",
		size = 16,
		color = COLOR.ink,
		position = UDim2.fromOffset(0, 220),
		frame = UDim2.new(1, 0, 0, 44),
		autoSize = false,
	})
	return e(PaperSheet, {
		position = UDim2.fromOffset(60, 76),
		size = UDim2.fromOffset(568, 330),
		paper = COLOR.cream,
		tilt = -1.5,
		band = review.band,
		bandColor = COLOR.companyTeal,
		fastener = "pin",
		padding = 20,
	}, content)
end

local function DepotResultBoard(props: DepotResultBoardProps): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		board = e(CorkBoard, { size = UDim2.fromOffset(1140, 420), position = UDim2.fromOffset(0, 26), frame = 20 }),
		tab = e("Frame", {
			Position = UDim2.fromOffset(380, 0),
			Size = UDim2.fromOffset(380, 64),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			texture = e(PaperTexture, { paper = COLOR.manilaDeep, corner = 6 }),
			label = e(PaperLabel, {
				text = props.title,
				role = "heading",
				size = 36,
				color = COLOR.ink,
				align = "center",
				frame = UDim2.fromScale(1, 1),
				autoSize = false,
				wrapped = false,
				zIndex = 2,
			}),
		}),
	}
	local review = props.review
	if review ~= nil then
		children.card = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, { sheet = reviewCard(review) })
		for index, sticky in review.stickies do
			local at: Vector2? = STICKY_AT[index]
			if at ~= nil then
				children[`sticky{index}`] = e("Frame", {
					Position = UDim2.fromOffset(at.X, at.Y),
					Size = UDim2.fromOffset(200, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					ZIndex = 4,
				}, {
					note = e(StickyNote, {
						text = `{sticky.title}\n{sticky.name}`,
						badge = badge(sticky.title),
						badgeSize = 24,
						width = 200,
						size = 18,
						tilt = STICKY_TILT[index],
						tape = Vector2.new(80, 20),
					}),
				})
			end
		end
	end
	return e("Frame", {
		Size = UDim2.fromOffset(1140, 446),
		BackgroundTransparency = 1,
	}, children)
end

return DepotResultBoard
