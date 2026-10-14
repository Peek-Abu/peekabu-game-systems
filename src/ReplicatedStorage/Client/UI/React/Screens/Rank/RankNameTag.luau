--!strict
--[=[
	RankNameTag: the overhead staff badge (Cleanup Crew "Clearance Level") at its RankConstants.TAG_PX design size (200x112): a lanyard strap
	in the level's colour down to a punch-cream ID card (PaperTag, hole at the top), the player's name (Oswald 22), the
	rank (Special Elite 15), the level code ("CL-2") and a lanyard-colour band along the card's foot. Presentational;
	the words and colour are RankViewModel.tag.

	@class RankNameTag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local RankConstants = require(ReplicatedStorage.Shared.Features.Rank.Data.RankConstants)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperTag = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTag)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)

local e = React.createElement

export type RankNameTagProps = {
	view: RankViewModel.TagView,
}

local COLOR = UIPaperConstants.COLOR
-- The design size the billboard maps (RankConstants.TAG_PX, read by RankTagSystem's WorldBillboard).
local DESIGN = RankConstants.TAG_PX
local STRAP = 22
local CARD = Vector2.new(DESIGN.X, DESIGN.Y - STRAP)
local BAND = 8

local function line(
	text: string,
	role: PaperLabel.Role,
	size: number,
	color: Color3,
	y: number,
	height: number
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		color = color,
		align = "center",
		position = UDim2.fromOffset(12, y),
		frame = UDim2.new(1, -24, 0, height),
		autoSize = false,
		wrapped = false,
		scaled = true,
	})
end

local function RankNameTag(props: RankNameTagProps): React.ReactNode
	local view = props.view
	return e("Frame", {
		Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
		BackgroundTransparency = 1,
	}, {
		strap = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(8, STRAP + 14),
			BackgroundColor3 = view.lanyard,
			BorderSizePixel = 0,
		}),
		card = e("Frame", {
			Position = UDim2.fromOffset(0, STRAP),
			Size = UDim2.fromOffset(CARD.X, CARD.Y),
			BackgroundTransparency = 1,
		}, {
			paper = e(PaperTag, { size = CARD, paper = COLOR.cream, hole = "top" }, {
				name = line(view.name, "heading", 22, COLOR.ink, 38, 24),
				rank = line(`{view.level}  {view.rank}`, "body", 15, COLOR.ink, 63, 17),
				band = e("Frame", {
					Position = UDim2.new(0, 0, 1, -BAND),
					Size = UDim2.new(1, 0, 0, BAND),
					BackgroundColor3 = view.lanyard,
					BorderSizePixel = 0,
				}),
			}),
		}),
	})
end

return RankNameTag
