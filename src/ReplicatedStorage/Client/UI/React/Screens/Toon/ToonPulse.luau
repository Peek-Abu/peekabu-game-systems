--!strict
--[=[
	ToonPulse: the kit's "press me!" for a button that is waiting for the player (owner 2026-11-14: an unpunched
	punch-in must obviously ask to be clicked). While `active`, its child swells and settles (ToonMotionViewModel.pulse)
	inside a soft glow in `color` (the kit's 9-slice glow, mint by default), with soap bubbles drifting on its corners
	(ToonSparkle; no stars). Inactive, it draws the child as it is. Reduced Motion keeps a steady glow, without the swell.
	Presentational (exempt; story in ToonPulse.story; the curve is specced in ToonMotionViewModel).

	@class ToonPulse
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonMotionViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonMotionViewModel)
local ToonSparkle = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSparkle)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local useToonPlay = require(ReplicatedStorage.Client.UI.React.Screens.Toon.useToonPlay)

local e = React.createElement

export type ToonPulseProps = {
	active: boolean,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	-- The glow's colour (default the kit's mint: "go").
	color: Color3?,
	-- How far the glow reaches past the child, in px.
	reach: number?,
	zIndex: number?,
	children: { [string]: React.ReactNode },
}

local PERIOD = UIToonConstants.MOTION.pulsePeriod

local function Glowing(props: ToonPulseProps): React.ReactNode
	local clock = useToonPlay(PERIOD, 0, nil, true)
	local reach = props.reach or 22
	local zIndex = props.zIndex or 1
	local scale = clock:map(function(alpha: number): number
		return ToonMotionViewModel.pulse(alpha * PERIOD).scale
	end)
	local glow = clock:map(function(alpha: number): number
		return ToonMotionViewModel.pulse(alpha * PERIOD).glow
	end)
	local body: { [string]: React.ReactNode } = { scale = e("UIScale", { Scale = scale }) }
	for key, node in props.children do
		body[key] = node
	end
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = zIndex,
	}, {
		glow = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 2 * reach, 1, 2 * reach),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.glow,
			ImageColor3 = props.color or UIToonConstants.shade("mint").hi,
			ImageTransparency = glow,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(48, 48, 80, 80),
			ZIndex = zIndex,
		}),
		body = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = zIndex + 1,
		}, body),
		bubbles = e(ToonSparkle, {
			spots = {
				{ position = UDim2.new(0, -4, 0, 6), size = 26 },
				{ position = UDim2.new(1, 4, 0, -2), size = 20 },
				{ position = UDim2.new(1, -2, 1, -10), size = 24 },
			},
			zIndex = zIndex + 5,
		}),
	})
end

local function ToonPulse(props: ToonPulseProps): React.ReactNode
	if props.active then
		return e(Glowing, props)
	end
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex or 1,
	}, props.children)
end

return ToonPulse
