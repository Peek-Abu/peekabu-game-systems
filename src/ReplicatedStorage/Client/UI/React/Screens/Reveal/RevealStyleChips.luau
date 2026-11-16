--!strict
--[=[
	RevealStyleChips: a new skin's colour style chips on the reveal, one per style above the buttons (each chip its
	two colour dots and its name); the picked one shows on the hero and Wear it! puts it on. `add` puts the row into
	the screen's nodes as `styles` (nothing for a skin with no styles). Split out of RevealScreen. Presentational
	(exempt; the chips specced in RevealViewModel; story in RevealScreen.story).

	@class RevealStyleChips
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.RevealViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

type Nodes = { [string]: React.ReactNode }

-- The style picked to wear, for the item it was picked on.
export type Picked = { key: string, style: number }

local RevealStyleChips = {}

-- A colour style chip's face: its two colours (the fur, then the outfit) as dots, then its name.
local function chipFace(chip: VM.StyleChip, size: number): Nodes
	local dot = size - 2
	local face: Nodes = {
		name = e(ToonText, {
			text = chip.name,
			textSize = size - 4,
			meaning = "grape",
			position = UDim2.fromOffset(dot * 2 + 14, 0),
			size = UDim2.new(1, -(dot * 2 + 18), 1, 0),
			fit = true,
		}),
	}
	for index, colour in chip.swatch do
		face[`dot{index}`] = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6 + (index - 1) * (dot + 2), 0.5, 0),
			Size = UDim2.fromOffset(dot, dot),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
		}, {
			round = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			edge = e("UIStroke", { Color = COLOR.ink, Thickness = 2 }),
		})
	end
	return face
end

--[=[
	Puts the style row into `nodes` (above the buttons, right-aligned at `margin`). `style` is the chip picked now;
	tapping a chip calls `setPicked` with `styleKey`.
]=]
function RevealStyleChips.add(
	nodes: Nodes,
	view: VM.View,
	style: number,
	styleKey: string,
	setPicked: (picked: Picked) -> (),
	phone: boolean,
	margin: number,
	buttonWidth: number,
	buttonHeight: number
)
	-- A new skin with colour styles: a chip per style above the buttons; the pick shows on the hero and Wear it! puts
	-- it on.
	local chips = view.styles
	if #chips > 0 then
		local chipSize = if phone then 14 else 26
		local chipHeight = chipSize + 22
		local rowWidth = math.floor(buttonWidth * 1.6)
		local chipWidth = math.floor((rowWidth - (#chips - 1) * 10) / #chips)
		local above = (if view.later then buttonHeight + (if phone then 24 else 70) else (if phone then 12 else 50))
			+ buttonHeight
			+ (if phone then 12 else 24)
		local row: Nodes = {}
		for index, chip in chips do
			row[`style{index}`] = e(ToonButton, {
				variant = "secondary",
				selected = index == style,
				content = chipFace(chip, chipSize),
				position = UDim2.fromOffset((index - 1) * (chipWidth + 10), 0),
				size = UDim2.fromOffset(chipWidth, chipHeight),
				zIndex = 6,
				onActivated = function()
					setPicked({ key = styleKey, style = index })
				end,
			})
		end
		nodes.styles = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -margin, 1, -above),
			Size = UDim2.fromOffset(rowWidth, chipHeight),
			BackgroundTransparency = 1,
			ZIndex = 6,
		}, row)
	end
end

return RevealStyleChips
