--!strict
--[=[
	ToonSparkle: Gleam's gold 4-point sparkles, the kit's "you earned something" mark (rewards, CTAs, gold numbers):
	one sparkle image per spot, each pulsing and turning a little on a stagger (ToonMotionViewModel.twinkle), driven by
	one looping TweenService value. `spots` places them (position and size in the parent). Presentational (exempt;
	story in ToonSparkle.story; the twinkle is specced).

	@class ToonSparkle
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonMotionViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonMotionViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local useToonPlay = require(ReplicatedStorage.Client.UI.React.Screens.Toon.useToonPlay)

local e = React.createElement

export type Spot = { position: UDim2, size: number }

export type ToonSparkleProps = {
	spots: { Spot },
	zIndex: number?,
}

local PERIOD = UIToonConstants.MOTION.sparklePeriod

local function ToonSparkle(props: ToonSparkleProps): React.ReactNode
	local clock = useToonPlay(PERIOD, 0, nil, true)
	local count = #props.spots
	local children: { [string]: React.ReactNode } = {}
	for index, spot in props.spots do
		local pulse = clock:map(function(alpha: number): number
			return ToonMotionViewModel.twinkle(alpha * PERIOD, index, count)
		end)
		children[`sparkle{index}`] = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = spot.position,
			Size = UDim2.fromOffset(spot.size, spot.size),
			Rotation = pulse:map(function(value: number): number
				return (1 - value) * 25
			end),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.sparkle,
			ZIndex = props.zIndex,
		}, {
			scale = e("UIScale", { Scale = pulse }),
		})
	end
	return e(React.Fragment, nil, children)
end

return ToonSparkle
