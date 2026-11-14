--!strict
--[=[
	ToonHighlight: the kit's "this one is waiting for you" mark (owner 2026-11-14: the button itself stays still; only a
	border colour gently pulses). While `active`, a rounded border in `color` (gold by default) sits just outside its
	child and breathes from strong to soft and back (ToonMotionViewModel.highlight). Nothing grows, glows or sparkles.
	Inactive, it draws the child as it is. Reduced Motion shows the border steady and strong.
	Presentational (exempt; story in ToonHighlight.story; the curve is specced in ToonMotionViewModel).

	@class ToonHighlight
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ToonMotionViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonMotionViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local useToonPlay = require(ReplicatedStorage.Client.UI.React.Screens.Toon.useToonPlay)

local e = React.createElement

export type ToonHighlightProps = {
	active: boolean,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	-- The border's colour (default the kit's gold).
	color: Color3?,
	-- The child's corner radius, so the border follows its shape (default the kit's button radius).
	radius: number?,
	-- How far outside the child the border sits, in px.
	gap: number?,
	thickness: number?,
	zIndex: number?,
	children: { [string]: React.ReactNode },
}

local PERIOD = UIToonConstants.MOTION.highlightPeriod

local function Border(
	props: { color: Color3, radius: number, gap: number, thickness: number, zIndex: number }
): React.ReactNode
	local clock = useToonPlay(PERIOD, 0, nil, true)
	local transparency = clock:map(function(alpha: number): number
		return ToonMotionViewModel.highlight(alpha * PERIOD)
	end)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 2 * props.gap, 1, 2 * props.gap),
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, props.radius + props.gap) }),
		border = e("UIStroke", {
			Color = props.color,
			Thickness = props.thickness,
			Transparency = transparency,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

local function ToonHighlight(props: ToonHighlightProps): React.ReactNode
	local zIndex = props.zIndex or 1
	local children: { [string]: React.ReactNode } = table.clone(props.children)
	if props.active then
		children.highlight = e(Border, {
			color = props.color or UIToonConstants.shade("gold").base,
			radius = props.radius or 24,
			gap = props.gap or 6,
			thickness = props.thickness or 5,
			zIndex = zIndex + 6,
		})
	end
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = zIndex,
	}, children)
end

return ToonHighlight
