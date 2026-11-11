--!strict
--[=[
	DepotRankChart: the hub's rank chart in the V1 kit: a cream ToonPanel with the grape "RANK CHART" band and its X,
	one row per rank from the top down (a lanyard-colour tag, the rank's name; ranks not reached yet are faded), the
	row you are on lifted onto a gold "YOU ARE HERE!" pill, and the next-rank line under them. Desktop 460x560 design
	px, phone 330x400, scaled to the screen (DepotRankChartViewModel.fit). Presentational; the words are
	DepotRankChartViewModel.chart.

	@class DepotRankChart
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local VM = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotRankChartViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)

local e = React.createElement

export type DepotRankChartProps = {
	view: VM.View,
	phone: boolean,
	scale: number,
	onClose: () -> (),
}

local function DepotRankChart(props: DepotRankChartProps): React.ReactNode
	local phone = props.phone
	local size = if phone then VM.PHONE_SIZE else VM.SIZE
	local band = if phone then 52 else 66
	local footer = if phone then 44 else 60
	local top = band + (if phone then 10 else 16)
	local rowsHeight = size.Y - top - footer - 10
	local rowHeight = math.floor(rowsHeight / math.max(#props.view.rows, 1))
	local textSize = if phone then 18 else 26
	local children: { [string]: React.ReactNode } = {}
	for index, row in props.view.rows do
		local y = top + (index - 1) * rowHeight
		children[`tag{index}`] = e("Frame", {
			BackgroundColor3 = row.colour,
			BackgroundTransparency = if row.reached then 0 else 0.55,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(if phone then 18 else 26, y + rowHeight * 0.2),
			Size = UDim2.fromOffset(if phone then 12 else 16, rowHeight * 0.6),
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
		if row.here then
			children[`here{index}`] = e(ToonPill, {
				text = row.name,
				meaning = "gold",
				hue = "gold",
				textSize = textSize,
				position = UDim2.fromOffset(if phone then 38 else 52, y + 2),
				size = UDim2.fromOffset(if phone then 170 else 240, rowHeight - 4),
				tilt = -2,
			})
			children[`youTag{index}`] = e(ToonText, {
				text = "YOU ARE HERE!",
				meaning = "gold",
				textSize = if phone then 14 else 20,
				align = "right",
				fit = true,
				anchor = Vector2.new(1, 0),
				position = UDim2.new(1, if phone then -14 else -22, 0, y),
				size = UDim2.fromOffset(if phone then 110 else 150, rowHeight),
				alignY = "center",
			})
		else
			children[`name{index}`] = e(ToonText, {
				text = row.name,
				font = "body",
				textSize = textSize,
				transparency = if row.reached then 0 else 0.5,
				fit = true,
				alignY = "center",
				position = UDim2.fromOffset(if phone then 40 else 56, y),
				size = UDim2.fromOffset(size.X - (if phone then 60 else 80), rowHeight),
			})
		end
	end
	children.line = e(ToonText, {
		text = props.view.line,
		meaning = "mint",
		textSize = if phone then 18 else 26,
		align = "center",
		fit = true,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -14),
		size = UDim2.new(1, -28, 0, footer - 16),
	})
	return e("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
	}, {
		scale = e("UIScale", { Scale = props.scale }),
		panel = e(ToonPanel, {
			size = size,
			pop = true,
			header = { title = "RANK CHART", height = band, titleSize = if phone then 22 else 30 },
			onClose = props.onClose,
			children = children,
		}),
	})
end

return DepotRankChart
