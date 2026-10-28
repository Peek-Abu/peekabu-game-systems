--!strict
--[=[
	DepotTimecardStamp: today's punch landing on the Timecard (TimecardMomentStore.stamp, set by TimecardMomentSystem).
	A coral rubber stamp drops onto today's day tile from big and see-through to its size and full ink in
	TimecardMomentSystem.STAMP_LANDS (the stamp sound plays as it lands), tilted like a hand stamp, and the banner
	under the tiles pops up with what the punch paid (gold for a reward, mint otherwise). Keyed by the punch, so each
	punch mounts fresh and animates again. Drawn in the clipboard card's 620x390 face; reduced motion shows it still.

	@class DepotTimecardStamp
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local TimecardMomentUtils = require(ReplicatedStorage.Client.Features.Timecard.Utils.TimecardMomentUtils)
local TimecardMomentSystem = require(ReplicatedStorage.Client.Features.Timecard.Systems.TimecardMomentSystem)
local useProgressTween = require(ReplicatedStorage.Client.UI.React.Hooks.useProgressTween)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonFlag = require(Toon.ToonFlag)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type Props = {
	moment: TimecardMomentUtils.Moment,
	banner: string,
}

type SlamProps = {
	tile: UDim2,
	banner: string,
	reward: boolean,
}

-- The card's day tiles (DepotTimecardPanel): 74x52 from x = 24, one every 83, at y = 180.
local TILE = Vector2.new(74, 52)

local function tile(day: number): UDim2
	return UDim2.fromOffset(24 + (day - 1) * 83, 180)
end

local function Slam(props: SlamProps): React.ReactNode
	local target, setTarget = React.useState(0)
	React.useEffect(function()
		setTarget(1)
	end, {})
	local landed = useProgressTween(target, TimecardMomentSystem.STAMP_LANDS)
	local popped = useProgressTween(target, 0.35)
	local ink = UIToonConstants.COLOR.danger
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8 }, {
		stamp = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = props.tile + UDim2.fromOffset(TILE.X / 2, TILE.Y / 2),
			Size = UDim2.fromOffset(TILE.X + 14, TILE.Y + 6),
			Rotation = -14,
			BackgroundColor3 = UIToonConstants.COLOR.white,
			BackgroundTransparency = landed:map(function(value: number): number
				return 1 - 0.85 * value
			end),
			ZIndex = 8,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
			scale = e("UIScale", {
				Scale = landed:map(function(value: number): number
					return 2.6 - 1.6 * value
				end),
			}),
			ring = e("UIStroke", {
				Color = ink,
				Thickness = 4,
				Transparency = landed:map(function(value: number): number
					return 1 - value
				end),
			}),
			word = e(ToonText, {
				text = "IN!",
				textSize = 30,
				meaning = "coral",
				align = "center",
				alignY = "center",
				size = UDim2.fromScale(1, 1),
				transparency = landed:map(function(value: number): number
					return 1 - value
				end),
				zIndex = 9,
			}),
		}),
		banner = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(310, 272),
			Size = UDim2.fromOffset(470, 54),
			BackgroundTransparency = 1,
			ZIndex = 9,
		}, {
			scale = e("UIScale", {
				Scale = popped:map(function(value: number): number
					return 0.4 + 0.6 * value
				end),
			}),
			flag = e(ToonFlag, {
				text = props.banner,
				hue = if props.reward then "gold" else "mint",
				textSize = 26,
				tilt = -2,
				size = UDim2.fromScale(1, 1),
				zIndex = 9,
			}),
		}),
	})
end

local function DepotTimecardStamp(props: Props): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		[props.moment.id] = e(Slam, {
			tile = tile(props.moment.day),
			banner = props.banner,
			reward = props.moment.reward ~= nil,
		}),
	}
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8 }, children)
end

return DepotTimecardStamp
