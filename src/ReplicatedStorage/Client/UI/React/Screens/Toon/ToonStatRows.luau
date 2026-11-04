--!strict
--[=[
	ToonStatRows: an employee's five stats, one row each: the stat's render, its name, and five pips filled gold up to
	its 1-5 value (the rest night-dark), each pip with an ink outline. Drawn on a dark plate (the About tab, the pick
	card, the Shop's hire page), so the names are white. A row tall enough (HINT_MIN_ROW) shows the stat's short line
	("Run faster.") under its name, smaller and in lilac; a short row (phones) shows the name alone. The rows come from InventoryViewModel.stats; nothing is per
	employee here. Presentational (exempt; story in ToonStatRows.story).

	@class ToonStatRows
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

type Nodes = { [string]: React.ReactNode }

export type ToonStatRow = { icon: UIAssets.ToonIcon, label: string, hint: string?, value: number }

export type ToonStatRowsProps = {
	rows: { ToonStatRow },
	-- One row's height in px (the icon is square at this size).
	row: number,
	-- Where the pips start, in px from the left.
	barX: number,
	textSize: number,
	position: UDim2?,
	size: UDim2,
}

local PIPS = 5
-- The shortest row (px) with room for the short line under the name.
local HINT_MIN_ROW = 40

local function ToonStatRows(props: ToonStatRowsProps): React.ReactNode
	local row = props.row
	local barX = props.barX
	local gold = UIToonConstants.shade("gold")
	local empty = UIToonConstants.shade("night").hi
	local face: Nodes = {}
	for index, stat in props.rows do
		local y = (index - 1) * row
		face[`icon{index}`] = e(ToonIcon, {
			icon = stat.icon,
			position = UDim2.fromOffset(0, y),
			size = UDim2.fromOffset(row, row),
			drop = 2,
		})
		local hint = if row >= HINT_MIN_ROW then stat.hint else nil
		local labelHeight = if hint ~= nil then math.floor(row * 0.58) else row
		face[`label{index}`] = e(ToonText, {
			text = stat.label,
			font = "body",
			color = COLOR.white,
			textSize = props.textSize,
			position = UDim2.fromOffset(row + 8, y),
			size = UDim2.fromOffset(barX - row - 12, labelHeight),
			alignY = if hint ~= nil then "bottom" else nil,
			fit = true,
		})
		face[`hint{index}`] = if hint ~= nil
			then e(ToonText, {
				text = hint,
				font = "body",
				color = UIToonConstants.shade("lilac").hi,
				textSize = math.floor(props.textSize * 0.62),
				position = UDim2.fromOffset(row + 8, y + labelHeight),
				size = UDim2.fromOffset(barX - row - 12, row - labelHeight),
				alignY = "top",
				fit = true,
			})
			else nil
		local pips: Nodes = {}
		for pip = 1, PIPS do
			local filled = pip <= stat.value
			pips[`pip{pip}`] = e("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale((pip - 1) / PIPS, 0.5),
				Size = UDim2.new(1 / PIPS, -6, 0.42, 0),
				BackgroundColor3 = if filled then COLOR.white else empty,
				BorderSizePixel = 0,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 2 }),
				gradient = if filled
					then e("UIGradient", { Rotation = 90, Color = ColorSequence.new(gold.hi, gold.lo) })
					else nil,
			})
		end
		face[`bar{index}`] = e("Frame", {
			Position = UDim2.fromOffset(barX, y),
			Size = UDim2.new(1, -barX, 0, row),
			BackgroundTransparency = 1,
		}, pips)
	end
	return e("Frame", {
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
	}, face)
end

return ToonStatRows
