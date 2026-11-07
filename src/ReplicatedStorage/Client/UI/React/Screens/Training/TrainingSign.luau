--!strict
--[=[
	TrainingSign: one stop's sign in the Training hall (and the hub's Training pad sign), in the V1 kit at its 600x170
	design size: a cream card with the stop's words, a grape number tab when it has one, and a gold lip while it is the
	stop the player is on. Presentational.

	@class TrainingSign
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)

local e = React.createElement

export type TrainingSignProps = {
	text: string,
	-- The stop's number ("1".."5"); nil for no tab.
	number: string?,
	active: boolean,
}

local DESIGN = Vector2.new(600, 170)

local function TrainingSign(props: TrainingSignProps): React.ReactNode
	local face: { [string]: React.ReactNode } = {
		words = e(ToonText, {
			text = props.text,
			font = "body",
			textSize = 44,
			position = UDim2.fromOffset(if props.number ~= nil then 110 else 24, 12),
			size = UDim2.new(1, if props.number ~= nil then -134 else -48, 1, -24),
			align = "center",
			wrapped = true,
			fit = true,
		}),
	}
	local children: { [string]: React.ReactNode } = {
		card = e(ToonPanel, {
			hue = if props.active then "gold" else "cream",
			size = DESIGN - Vector2.new(0, 10),
			position = UDim2.fromOffset(0, 10),
			children = face,
		}),
	}
	local number = props.number
	if number ~= nil then
		local tab: { [string]: React.ReactNode } = {
			number = e(ToonText, {
				text = number,
				textSize = 52,
				size = UDim2.fromScale(1, 1),
				align = "center",
			}),
		}
		children.tab = e(ToonSurface, {
			hue = "grape",
			radius = 22,
			position = UDim2.fromOffset(18, 0),
			size = UDim2.fromOffset(84, 84),
			zIndex = 5,
			children = tab,
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
		BackgroundTransparency = 1,
	}, children)
end

return TrainingSign
