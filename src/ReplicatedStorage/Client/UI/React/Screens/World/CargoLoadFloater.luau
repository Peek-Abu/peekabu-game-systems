--!strict
--[=[
	CargoLoadFloater: a load floater in the V1 kit at its 340x130 design size, rising off the truck as cargo is banked.
	Bonus (the Gleam earned): a grape plate on the depth stack turned 5° with the coin render breaking its left end, the
	amount ("+40 Gleam") as a big stroked gold number and Gleam sparkles round it. Clearance (stray trash): "+15" as a
	big stroked mint number over a white CLEARED. `fade` (0 → 1) fades the whole floater as one group (a CanvasGroup),
	driven by CargoFeedbackSystem's tween, so fading never re-renders. Presentational; the words are
	CargoWorldViewModel.floater.

	@class CargoLoadFloater
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)

local e = React.createElement

export type CargoLoadFloaterProps = {
	view: CargoWorldViewModel.FloaterView,
	fade: React.Binding<number>,
}

local PLATE = Vector2.new(286, 84)
local COIN = 92

local function bonus(view: CargoWorldViewModel.FloaterView): { [string]: React.ReactNode }
	local face: { [string]: React.ReactNode } = {
		amount = e(ToonText, {
			text = view.text,
			meaning = "gold",
			textSize = 52,
			position = UDim2.fromOffset(COIN * 0.5, 0),
			size = UDim2.new(1, -COIN * 0.5 - 14, 1, 0),
			align = "center",
			fit = true,
		}),
	}
	return {
		plate = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 14, 0.5, -4),
			Size = UDim2.fromOffset(PLATE.X, PLATE.Y),
			Rotation = 5,
			BackgroundTransparency = 1,
		}, {
			surface = e(ToonSurface, {
				hue = "grape",
				radius = 999,
				pattern = "bubbles",
				size = UDim2.new(1, 0, 1, -7),
				children = face,
			}),
			coin = e(ToonIcon, {
				icon = "gleam",
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.new(0, 6, 0.5, -6),
				size = UDim2.fromOffset(COIN, COIN),
				rotation = -8,
				drop = 5,
				zIndex = 5,
			}),
		}),
		sparkles = e(ToonSparkle, {
			spots = {
				{ position = UDim2.fromOffset(300, 18), size = 28 },
				{ position = UDim2.fromOffset(62, 112), size = 20 },
				{ position = UDim2.fromOffset(212, 120), size = 16 },
			},
			zIndex = 6,
		}),
	}
end

local function clearance(view: CargoWorldViewModel.FloaterView): { [string]: React.ReactNode }
	local nodes: { [string]: React.ReactNode } = {
		amount = e(ToonText, {
			text = view.text,
			meaning = "mint",
			textSize = 76,
			size = UDim2.new(1, 0, 0, 90),
			align = "center",
			fit = true,
		}),
	}
	local caption = view.caption
	if caption ~= nil then
		nodes.caption = e(ToonText, {
			text = caption,
			textSize = 26,
			position = UDim2.fromOffset(0, 90),
			size = UDim2.new(1, 0, 0, 34),
			align = "center",
			fit = true,
		})
	end
	return nodes
end

local function CargoLoadFloater(props: CargoLoadFloaterProps): React.ReactNode
	local view = props.view
	return e("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = props.fade,
	}, if view.bonus then bonus(view) else clearance(view))
end

return CargoLoadFloater
