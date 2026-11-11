--!strict
--[=[
	DepotClockSign: the sign over the hub's weekly time clock in the V1 kit at its 320x150 design size (owner 11-11: the
	small boards must match the game's UI): a grape ToonPanel with the clock render breaking its top-left corner, TIME
	CLOCK in stroked gold display type, the line in white body type and the reward on a mint pill with the key render.
	Presentational; the words are DepotWorldViewModel.clockSign.

	@class DepotClockSign
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)

local e = React.createElement

export type DepotClockSignProps = {
	view: DepotWorldViewModel.ClockSignView,
}

local SIGN = Vector2.new(320, 150)
local ICON = 74

local function DepotClockSign(props: DepotClockSignProps): React.ReactNode
	local view = props.view
	local face: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = view.title,
			meaning = "gold",
			textSize = 34,
			position = UDim2.fromOffset(ICON - 2, 10),
			size = UDim2.new(1, -ICON - 10, 0, 40),
			fit = true,
		}),
		line = e(ToonText, {
			text = view.line,
			font = "body",
			color = Color3.new(1, 1, 1),
			textSize = 20,
			position = UDim2.fromOffset(ICON - 2, 50),
			size = UDim2.new(1, -ICON - 10, 0, 26),
			fit = true,
		}),
	}
	return e("Frame", { Size = UDim2.fromOffset(SIGN.X, SIGN.Y), BackgroundTransparency = 1 }, {
		plate = e(ToonSurface, {
			hue = "grape",
			radius = 22,
			position = UDim2.fromOffset(14, 14),
			size = UDim2.fromOffset(SIGN.X - 22, SIGN.Y - 22),
			children = face,
		}),
		icon = e(ToonIcon, {
			icon = "clock",
			size = UDim2.fromOffset(ICON, ICON),
			position = UDim2.fromOffset(0, 0),
			rotation = -8,
			zIndex = 4,
		}),
		reward = e(ToonPill, {
			text = view.reward,
			hue = "mint",
			icon = "key",
			textSize = 18,
			small = true,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 6, 1, -14),
			size = UDim2.fromOffset(SIGN.X - 70, 34),
			zIndex = 5,
		}),
	})
end

return DepotClockSign
