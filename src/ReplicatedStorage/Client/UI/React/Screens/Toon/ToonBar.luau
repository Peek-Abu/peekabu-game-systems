--!strict
--[=[
	ToonBar: a meter in the kit's style: a deep track with the ink outline and an inner shadow, a glossy capsule fill
	by kind (`gloom`: the violet goo with bubbles and a glossy meniscus at its leading edge; `xp`: mint; `stamina`: gold;
	`load`: grape) and an optional stroked label across it ("312 / 530"). `fill` is 0..1, a number or a binding (a
	tween). Presentational (exempt; story in ToonBar.story).

	@class ToonBar
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local shade = UIToonConstants.shade

export type Kind = "gloom" | "xp" | "stamina" | "load"

export type ToonBarProps = {
	kind: Kind,
	fill: number | React.Binding<number>,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	label: string?,
	labelSize: number?,
	zIndex: number?,
	layoutOrder: number?,
}

local FILL: { [Kind]: { Color3 } } = {
	gloom = { COLOR.gooHi, COLOR.gooBase, COLOR.gooLo },
	xp = { shade("mint").hi, shade("mint").base, shade("mint").lo },
	stamina = { shade("gold").hi, shade("gold").base, shade("gold").lo },
	load = { shade("grape").hi, shade("grape").base, shade("grape").lo },
}

local function ToonBar(props: ToonBarProps): React.ReactNode
	local fill: React.Binding<number> = if typeof(props.fill) == "number"
		then React.createBinding(props.fill)
		else props.fill
	local stops = FILL[props.kind]
	local gloom = props.kind == "gloom"
	local fillChildren: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		gradient = e("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, stops[1]),
				ColorSequenceKeypoint.new(0.55, stops[2]),
				ColorSequenceKeypoint.new(1, stops[3]),
			}),
		}),
		gloss = e("Frame", {
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.new(1, -12, 0.36, 0),
			BackgroundColor3 = COLOR.white,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	}
	if gloom then
		fillChildren.bubbles = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.patternBubbles,
			ImageTransparency = 0.55,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(44, 44),
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		-- The glossy meniscus riding the leading edge.
		fillChildren.meniscus = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0, 20, 1, 8),
			BackgroundColor3 = COLOR.gooHi,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }),
			gradient = e("UIGradient", {
				Color = ColorSequence.new(Color3.fromHex("E3D2FF"), COLOR.gooBase),
				Rotation = 60,
			}),
		})
	end
	fillChildren.minimum = e("UISizeConstraint", { MinSize = Vector2.new(24, 0) })
	local labelSize = props.labelSize or 24
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = COLOR.track,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		stroke = e("UIStroke", {
			Color = COLOR.ink,
			Thickness = 4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		-- The inner shadow along the track's top.
		shade = e("Frame", {
			Size = UDim2.fromScale(1, 0.45),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		fill = e("Frame", {
			Size = fill:map(function(value: number): UDim2
				local clamped = math.clamp(value, 0, 1)
				-- A sliver still reads as a rounded capsule (the size constraint keeps it 24 px wide at least).
				return UDim2.fromScale(clamped, 1)
			end),
			Visible = fill:map(function(value: number): boolean
				return value > 0
			end),
			BackgroundColor3 = stops[2],
			BorderSizePixel = 0,
			ZIndex = 2,
		}, fillChildren),
		label = if props.label ~= nil
			then e(ToonText, {
				text = props.label,
				textSize = labelSize,
				size = UDim2.fromScale(1, 1),
				align = "center",
				fit = true,
				zIndex = 4,
			})
			else nil,
	})
end

return ToonBar
