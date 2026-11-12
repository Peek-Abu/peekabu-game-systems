--!strict
--[=[
	DepotRankBoard: the rank chart on the hub's rank poster in the V1 kit at its 420x588 design size (owner 11-12, kit
	mock round 2 #2: numbers and pictures, not sentences): a lilac kit panel under a RANKS band with the trophy render,
	and a ladder of numbered steps, one per rank in its lanyard colour, climbing left to right. The viewer's step is
	lifted and ringed in lilac with a YOU pin above it. The rank names stay in the close-up chart (depot.RankChart).
	Presentational; the view is DepotSignViewModel.ranks.

	@class DepotRankBoard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotSignViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotSignViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type DepotRankBoardProps = {
	view: DepotSignViewModel.RanksView,
}

local BOARD = Vector2.new(420, 588)
local PANEL = Vector2.new(380, 548)
local HEADER = 76
local PAD = 18
local GAP = 6
-- The ladder's tallest step (px) and how far the viewer's step lifts.
local TALLEST = 330
local LIFT = 10
local INK = UIToonConstants.COLOR.ink

local function step(view: DepotSignViewModel.Step, index: number, width: number): React.ReactNode
	local height = math.floor(TALLEST * view.height)
	local children: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		stroke = e("UIStroke", {
			Color = if view.you then UIToonConstants.shade("lilac").hi else INK,
			Thickness = if view.you then 6 else 4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		shine = e("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(
				view.color:Lerp(Color3.new(1, 1, 1), 0.35),
				view.color:Lerp(Color3.new(0, 0, 0), 0.2)
			),
		}),
		number = e(ToonText, {
			text = view.number,
			meaning = "gold",
			textSize = 34,
			align = "center",
			position = UDim2.fromOffset(0, 6),
			size = UDim2.new(1, 0, 0, 40),
		}),
	}
	local x = PAD + (index - 1) * (width + GAP)
	-- Px up from the face's bottom edge.
	local raise = PAD + 8 + (if view.you then LIFT else 0)
	local block = e("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, x, 1, -raise),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = view.color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, children)
	if not view.you then
		return block
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		block = block,
		pin = e(ToonPill, {
			text = "YOU",
			hue = "lilac",
			textSize = 22,
			small = true,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0, x + width / 2, 1, -raise - height - 8),
			size = UDim2.fromOffset(78, 34),
			zIndex = 5,
		}),
	})
end

local function DepotRankBoard(props: DepotRankBoardProps): React.ReactNode
	local view = props.view
	local count = math.max(1, #view.steps)
	local width = math.floor((PANEL.X - 2 * PAD - (count - 1) * GAP) / count)
	local face: { [string]: React.ReactNode } = {}
	for index, entry in view.steps do
		face[`step{index}`] = step(entry, index, width)
	end
	return e("Frame", { Size = UDim2.fromOffset(BOARD.X, BOARD.Y), BackgroundTransparency = 1 }, {
		panel = e(ToonPanel, {
			position = UDim2.fromOffset((BOARD.X - PANEL.X) / 2, (BOARD.Y - PANEL.Y) / 2 + 6),
			size = PANEL,
			hue = "lilac",
			header = { title = view.title, icon = "trophy", height = HEADER, titleSize = 40 },
			children = face,
		}),
	})
end

return DepotRankBoard
