--!strict
--[=[
	DepotDailySign: the hub's daily bonus sheet in the V1 kit at its 300x380 design size (owner 11-11: the small boards
	must match the game's UI and each look its own): a sticky-note yellow ToonPanel, tilted a little like a note pinned to
	the wall, under a coral DAILY BONUS band with the gift render; today's work order in stroked grape display type, the
	line in body type, and the Credits render with a gold BONUS! stamp at its foot. Presentational; the words are
	DepotWorldViewModel.dailySign.

	@class DepotDailySign
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.DepotWorldViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)

local e = React.createElement

export type DepotDailySignProps = {
	view: DepotWorldViewModel.DailySignView,
}

local SIGN = Vector2.new(300, 380)
local PANEL = Vector2.new(264, 340)
local HEADER = 64
local PAD = 20

local function DepotDailySign(props: DepotDailySignProps): React.ReactNode
	local view = props.view
	local top = HEADER + 22
	local face: { [string]: React.ReactNode } = {
		job = e(ToonText, {
			text = view.job,
			meaning = "grape",
			textSize = 32,
			wrapped = true,
			align = "center",
			position = UDim2.fromOffset(PAD, top),
			size = UDim2.new(1, -2 * PAD, 0, 104),
			fit = true,
		}),
		line = e(ToonText, {
			text = view.line,
			font = "body",
			textSize = 19,
			wrapped = true,
			align = "center",
			position = UDim2.fromOffset(PAD, top + 112),
			size = UDim2.new(1, -2 * PAD, 0, 50),
			fit = true,
		}),
		credits = e(ToonIcon, {
			icon = "credits",
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.38, 0, 1, -14),
			size = UDim2.fromOffset(62, 62),
		}),
		stamp = e(ToonPill, {
			text = "BONUS!",
			hue = "coral",
			meaning = "white",
			textSize = 20,
			small = true,
			tilt = -8,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0.5, 0, 1, -24),
			size = UDim2.fromOffset(104, 36),
		}),
	}
	return e("Frame", { Size = UDim2.fromOffset(SIGN.X, SIGN.Y), BackgroundTransparency = 1 }, {
		note = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(PANEL.X, PANEL.Y),
			Rotation = 2.5,
			BackgroundTransparency = 1,
		}, {
			panel = e(ToonPanel, {
				size = PANEL,
				hue = "gold",
				header = { title = view.title, icon = "gift", height = HEADER, titleSize = 28 },
				children = face,
			}),
		}),
		pin = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(SIGN.X / 2, 16),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Color3.fromRGB(220, 60, 60),
			BorderSizePixel = 0,
			ZIndex = 6,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
	})
end

return DepotDailySign
