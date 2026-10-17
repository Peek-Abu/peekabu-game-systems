--!strict
--[=[
	ToonWipe: the kit's "dirty -> clean" moment. Laid over a panel's face as it opens, a smear of Gloom covers it and a
	gold squeegee blade sweeps left to right, leaving the panel clean and glossy behind it (ToonMotionViewModel.wipe:
	the dirt's transparency gradient and where the blade is). It plays once on mount and again when `replay` changes;
	afterwards nothing of it is drawn. Presentational (exempt; story in ToonWipe.story; the sweep is specced).

	@class ToonWipe
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonMotionViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonMotionViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local useToonPlay = require(ReplicatedStorage.Client.UI.React.Screens.Toon.useToonPlay)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local MOTION = UIToonConstants.MOTION

export type ToonWipeProps = {
	radius: number,
	-- Changing it plays the wipe again.
	replay: string?,
	delay: number?,
	zIndex: number?,
}

-- The smudges in the smear (scale position, size in px).
local SMUDGES = {
	{ x = 0.18, y = 0.3, size = 70 },
	{ x = 0.55, y = 0.62, size = 110 },
	{ x = 0.83, y = 0.25, size = 60 },
	{ x = 0.36, y = 0.8, size = 54 },
}

local function sequence(points: { ToonMotionViewModel.Point }): NumberSequence
	local keys: { NumberSequenceKeypoint } = {}
	for _, point in points do
		table.insert(keys, NumberSequenceKeypoint.new(point.time, point.value))
	end
	return NumberSequence.new(keys)
end

local function ToonWipe(props: ToonWipeProps): React.ReactNode
	local alpha = useToonPlay(MOTION.wipeSeconds, props.delay or MOTION.wipeDelay, props.replay)
	local wipe = alpha:map(ToonMotionViewModel.wipe)
	local smear: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, props.radius) }),
		gradient = e("UIGradient", {
			Transparency = wipe:map(function(value: ToonMotionViewModel.Wipe): NumberSequence
				return sequence(value.points)
			end),
		}),
		bubbles = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.patternBubbles,
			ImageTransparency = 0.6,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(60, 60),
		}),
	}
	for index, smudge in SMUDGES do
		smear[`smudge{index}`] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(smudge.x, smudge.y),
			Size = UDim2.fromOffset(smudge.size, smudge.size * 0.8),
			BackgroundColor3 = COLOR.gooLo,
			BorderSizePixel = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = alpha:map(function(value: number): boolean
			return value < 1
		end),
		ZIndex = props.zIndex,
	}, {
		-- A CanvasGroup so the one gradient fades the whole smear, smudges and all, rounded to the panel.
		smear = e("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.dirt,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, smear),
		blade = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = wipe:map(function(value: ToonMotionViewModel.Wipe): UDim2
				return UDim2.fromScale(value.edge, 0.5)
			end),
			Size = UDim2.new(0, 18, 1, 24),
			Rotation = 10,
			Visible = wipe:map(function(value: ToonMotionViewModel.Wipe): boolean
				return value.edge > 0 and value.edge < 1
			end),
			BackgroundColor3 = UIToonConstants.shade("gold").base,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 4 }),
			gradient = e("UIGradient", {
				Color = ColorSequence.new(UIToonConstants.shade("gold").hi, UIToonConstants.shade("gold").lo),
			}),
		}),
	})
end

return ToonWipe
