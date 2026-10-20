--!strict
--[=[
	ToonPill: a capsule on the kit's stack for a number or a short tag: the Gleam counter (a gold number with the coin
	render overlapping the pill's left end), a slot's charge or price, a "TONIGHT" / "LV 3" / "CAUGHT" tag (`tilt`
	gives a sticker angle). `trailing` draws a node over the right end (the + button). Presentational (exempt; story in
	ToonPill.story).

	@class ToonPill
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonIcon = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonIcon)
local ToonSurface = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSurface)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

export type ToonPillProps = {
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	hue: UIToonConstants.Hue?,
	meaning: UIToonConstants.Meaning?,
	textSize: number?,
	-- A render overlapping the left end, `iconSize` px square (default 1.5x the pill's text).
	icon: UIAssets.ToonIcon?,
	iconSize: number?,
	tilt: number?,
	small: boolean?,
	trailing: React.ReactNode?,
	-- Room kept clear at the right for `trailing` (px).
	trailingWidth: number?,
	-- The label's side padding (px, default 12): a small tag sized from its measured text
	-- (ToonStyleViewModel.pillWidth) takes less.
	padX: number?,
	zIndex: number?,
	layoutOrder: number?,
}

local function ToonPill(props: ToonPillProps): React.ReactNode
	local textSize = props.textSize or 26
	local iconSize = props.iconSize or math.floor(textSize * 1.9)
	local hasIcon = props.icon ~= nil
	local padX = props.padX or 12
	local left = if hasIcon then iconSize * 0.62 else padX
	local right = props.trailingWidth or padX
	local hue: UIToonConstants.Hue = props.hue or "cream"
	local face: { [string]: React.ReactNode } = {}
	face.label = e(ToonText, {
		text = props.text,
		textSize = textSize,
		meaning = props.meaning,
		position = UDim2.fromOffset(left, -1),
		size = UDim2.new(1, -left - right, 1, 0),
		align = "center",
		fit = true,
	})
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		Rotation = props.tilt,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
	}, {
		surface = e(ToonSurface, {
			hue = hue,
			size = UDim2.fromScale(1, 1),
			radius = 999,
			small = props.small ~= false,
			pattern = if hue == "cream" then "sparkle" else nil,
			children = face,
		}),
		icon = if hasIcon
			then e(ToonIcon, {
				icon = props.icon,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.new(0, iconSize * 0.18, 0.5, -2),
				size = UDim2.fromOffset(iconSize, iconSize),
				drop = 4,
				zIndex = 3,
			})
			else nil,
		trailing = props.trailing,
	})
end

return ToonPill
