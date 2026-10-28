--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local Surface = require(Toon.ToonSurface)
local Text = require(Toon.ToonText)
local Bar = require(Toon.ToonBar)
local Button = require(Toon.ToonButton)
local Icon = require(Toon.ToonIcon)
local Style = require(Toon.UIToonConstants)
local e = React.createElement
export type Props = {
	phone: boolean,
	order: string,
	progress: number,
	target: number,
	claimed: boolean,
	onUnpin: () -> (),
}
local function Panel(props: Props): React.ReactNode
	local content: { [string]: React.ReactNode } = {
		icon = e(Icon, {
			icon = "jobs",
			position = UDim2.fromOffset(-8, -10),
			size = UDim2.fromOffset(48, 48),
			rotation = -12,
			zIndex = 3,
		}),
		title = e(Text, {
			text = if props.claimed then "WORK ORDER PAID" else props.order,
			font = "body",
			color = Style.COLOR.white,
			textSize = if props.phone then 17 else 22,
			position = UDim2.fromOffset(42, 6),
			size = UDim2.new(1, -86, 0, if props.phone then 22 else 28),
			fit = true,
		}),
		meter = e(Bar, {
			kind = "xp",
			fill = math.clamp(props.progress / math.max(1, props.target), 0, 1),
			label = `{props.progress} / {props.target}`,
			labelSize = if props.phone then 16 else 21,
			position = UDim2.fromOffset(12, if props.phone then 34 else 46),
			size = UDim2.new(1, -24, 0, if props.phone then 20 else 34),
		}),
		hide = e(Button, {
			text = "×",
			textSize = 20,
			variant = "secondary",
			position = UDim2.new(1, -44, 0, 6),
			size = UDim2.fromOffset(32, 30),
			onActivated = props.onUnpin,
		}),
	}
	return e("Frame", {
		AnchorPoint = if props.phone then Vector2.zero else Vector2.new(1, 0),
		Position = if props.phone then UDim2.fromOffset(14, 136) else UDim2.new(1, -24, 0, 180),
		Size = if props.phone then UDim2.fromOffset(240, 64) else UDim2.fromOffset(370, 104),
		BackgroundTransparency = 1,
	}, {
		card = e(
			Surface,
			{ hue = "grape", pattern = "bubbles", radius = 16, size = UDim2.fromScale(1, 1), children = content }
		),
	})
end
return Panel
