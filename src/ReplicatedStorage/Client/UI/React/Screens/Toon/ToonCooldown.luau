--!strict
--[=[
	ToonCooldown: an ability's cooldown on a cream chip: the stopwatch render overlapping the chip's left end (never
	above or below it, so a chip in a scrolling list is never clipped), the
	number big in the gold numbers' style and its unit word ("sec", "min") small in Fredoka under it, so the unit never
	reads as a digit (owner, 2026-11-12: "8s" looked plain and its "s" like a 5). The words come from
	ToonStyleViewModel.cooldown. Used wherever an ability card shows its cooldown (the starting-employee pick, the
	Shop's hire page, the Inventory's character page). Presentational (exempt; story in ToonCooldown.story).

	@class ToonCooldown
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ToonIcon = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonIcon)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local ToonSurface = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSurface)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

export type ToonCooldownProps = {
	-- The cooldown in seconds.
	seconds: number,
	-- The chip's size; the number, the word and the stopwatch scale from its height.
	size: UDim2,
	-- The chip's height in px (the same as `size`'s), which the type and the render are sized from.
	height: number,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
}

-- The smallest type the chip draws (px, before the HUD scale): the readable floor.
local MIN_TEXT = 12

local function ToonCooldown(props: ToonCooldownProps): React.ReactNode
	local parts = ToonStyleViewModel.cooldown(props.seconds)
	local height = props.height
	local unitSize = math.max(MIN_TEXT, math.floor(height * 0.24))
	local valueSize = math.max(MIN_TEXT + 4, math.floor(height * 0.5))
	local stopwatch = math.floor(height * 0.62)
	-- The number and its word stand as one block right of the stopwatch.
	local left = math.floor(stopwatch * 0.42)
	local blockHeight = valueSize + unitSize + 2
	local top = math.floor((height - UIToonConstants.DEPTH.drop - blockHeight) / 2) + 1
	local face: { [string]: React.ReactNode } = {
		value = e(ToonText, {
			text = parts.value,
			textSize = valueSize,
			meaning = "gold",
			position = UDim2.fromOffset(left, top),
			size = UDim2.new(1, -left - 6, 0, valueSize + 2),
			align = "center",
			fit = true,
		}),
		unit = e(ToonText, {
			text = parts.unit,
			font = "body",
			color = UIToonConstants.COLOR.ink,
			textSize = unitSize,
			position = UDim2.fromOffset(left, top + valueSize + 2),
			size = UDim2.new(1, -left - 6, 0, unitSize + 2),
			align = "center",
			fit = true,
		}),
	}
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		surface = e(ToonSurface, {
			hue = "cream",
			radius = 999,
			small = true,
			pattern = "rings",
			size = UDim2.fromScale(1, 1),
			children = face,
		}),
		stopwatch = e(ToonIcon, {
			icon = "stopwatch",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0, math.floor(stopwatch * 0.06), 0.5, -math.floor(UIToonConstants.DEPTH.drop / 2)),
			size = UDim2.fromOffset(stopwatch, stopwatch),
			rotation = -14,
			drop = 3,
			zIndex = 3,
		}),
	})
end

return ToonCooldown
