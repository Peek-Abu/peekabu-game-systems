--!strict
--[=[
	ToonSlider.story: three volume sliders (grape, mint and gold fills) and a disabled one on a cream settings card,
	each holding its own value: drag with the mouse, click to jump, hover and use Left / Right or A / D to step 5%.
	`Width` resizes the sliders. In Studio's edit mode (UI Labs).

	@class ToonSlider.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)
local ToonSlider = require(Toon.ToonSlider)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)

local e = React.createElement

type Row = { key: string, label: string, kind: ToonBar.Kind, start: number, disabled: boolean? }

local ROWS: { Row } = {
	{ key = "music", label = "Music & ambience", kind = "load", start = 0.8 },
	{ key = "sfx", label = "Sound effects", kind = "xp", start = 0.55 },
	{ key = "shake", label = "Camera shake", kind = "stamina", start = 1 },
	{ key = "off", label = "Disabled", kind = "load", start = 0.3, disabled = true },
}

local function Row(props: { row: Row, width: number, y: number }): React.ReactNode
	local value, setValue = React.useState(props.row.start)
	return e("Frame", {
		Position = UDim2.fromOffset(40, props.y),
		Size = UDim2.fromOffset(props.width, 80),
		BackgroundTransparency = 1,
	}, {
		label = e(ToonText, {
			text = props.row.label,
			font = "body",
			textSize = 22,
			size = UDim2.new(1, 0, 0, 28),
			alignY = "top",
		}),
		slider = e(ToonSlider, {
			value = value,
			min = 0,
			max = 1,
			step = 0.05,
			kind = props.row.kind,
			disabled = props.row.disabled,
			position = UDim2.fromOffset(0, 32),
			size = UDim2.new(1, 0, 0, 48),
			onChange = setValue,
		}),
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = { Width = 560 },
}, function(props)
	local width = props.controls.Width
	local rows: { [string]: React.ReactNode } = {}
	for index, row in ROWS do
		rows[row.key] = e(Row, { row = row, width = width, y = 30 + (index - 1) * 96 })
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("2B1856"),
	}, {
		card = e(ToonSurface, {
			hue = "cream",
			pattern = "sparkle",
			radius = 26,
			position = UDim2.fromOffset(60, 60),
			size = UDim2.fromOffset(width + 80, 30 + #ROWS * 96 + 30),
			children = rows,
		}),
	})
end)
