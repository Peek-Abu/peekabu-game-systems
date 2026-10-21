--!strict
--[=[
	CargoLoadFloater: a load floater in the V1 kit at its 340x130 design size, rising off the truck as cargo is banked.
	Bonus (the Credits earned): the amount ("+40 Credits") as a big stroked gold number with the coin render beside it and
	Gleam sparkles round it. Clearance (stray trash): "+15" as a big stroked mint number over a white CLEARED. `fade`
	(0 → 1) is every part's transparency, driven by CargoFeedbackSystem's tween, so fading never re-renders. (No
	CanvasGroup and no plate: a CanvasGroup does not draw inside a BillboardGui, and the depth stack's layers cannot
	fade as one, so the floater is type and renders only, each fading by its own binding.) Presentational; the words are
	CargoWorldViewModel.floater.

	@class CargoLoadFloater
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonText = require(Toon.ToonText)

local e = React.createElement

export type CargoLoadFloaterProps = {
	view: CargoWorldViewModel.FloaterView,
	fade: React.Binding<number>,
}

local COIN = 84

local function bonus(view: CargoWorldViewModel.FloaterView, fade: React.Binding<number>): { [string]: React.ReactNode }
	return {
		coin = e(ToonIcon, {
			icon = "gleam",
			anchor = Vector2.new(0, 0.5),
			position = UDim2.new(0, 6, 0.5, -4),
			size = UDim2.fromOffset(COIN, COIN),
			rotation = -8,
			drop = 5,
			transparency = fade,
			zIndex = 3,
		}),
		amount = e(ToonText, {
			text = view.text,
			meaning = "gold",
			textSize = 60,
			position = UDim2.fromOffset(COIN + 6, 0),
			size = UDim2.new(1, -COIN - 12, 1, 0),
			fit = true,
			transparency = fade,
			zIndex = 2,
		}),
		sparkles = e(ToonSparkle, {
			spots = {
				{ position = UDim2.fromOffset(318, 22), size = 30 },
				{ position = UDim2.fromOffset(70, 112), size = 20 },
				{ position = UDim2.fromOffset(250, 114), size = 18 },
			},
			transparency = fade,
			zIndex = 4,
		}),
	}
end

local function clearance(
	view: CargoWorldViewModel.FloaterView,
	fade: React.Binding<number>
): { [string]: React.ReactNode }
	local nodes: { [string]: React.ReactNode } = {
		amount = e(ToonText, {
			text = view.text,
			meaning = "mint",
			textSize = 76,
			size = UDim2.new(1, 0, 0, 90),
			align = "center",
			fit = true,
			transparency = fade,
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
			transparency = fade,
		})
	end
	return nodes
end

local function CargoLoadFloater(props: CargoLoadFloaterProps): React.ReactNode
	local view = props.view
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, if view.bonus then bonus(view, props.fade) else clearance(view, props.fade))
end

return CargoLoadFloater
