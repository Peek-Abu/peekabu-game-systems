--!strict
--[=[
	ToonRarityFrame: the extras that make a higher rarity feel special on a card, drawn in two parts so the glow can
	sit behind the card and the trim in front of it:
	- `part = "halo"` (a sibling drawn just behind the card, same size and position): Legendary's gold halo, Odd's red
	  glow. Nothing for lower rarities.
	- `part = "trim"` (inside the card, over its art): a rim in the rarity's colour from Rare up (thicker for Epic and
	  above), Legendary's twinkling gold sparkles, Odd's goo dripping off the top edge.
	Default and Uncommon get no extras: the stage colour alone says it. Presentational (exempt; story in
	ToonRarityFrame.story).

	@class ToonRarityFrame
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonGoo = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonGoo)
local ToonSparkle = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSparkle)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

export type Part = "halo" | "trim"

export type ToonRarityFrameProps = {
	rarity: UIToonConstants.Rarity,
	part: Part,
	-- The card's width (design px) and corner radius (the goo keeps clear of the corners; the rim follows them).
	width: number,
	radius: number,
	-- For the halo: the card's own size and position (it is drawn as the card's sibling).
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
}

local RIM: { [UIToonConstants.Rarity]: number } = {
	default = 0,
	uncommon = 0,
	rare = 3,
	epic = 5,
	legendary = 5,
	odd = 5,
}

local function halo(props: ToonRarityFrameProps): React.ReactNode
	if props.rarity ~= "legendary" and props.rarity ~= "odd" then
		return nil
	end
	local shade = UIToonConstants.rarity(props.rarity)
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, {
		glow = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 64, 1, 64),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.glow,
			ImageColor3 = shade.base,
			ImageTransparency = 0.15,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(48, 48, 80, 80),
			ZIndex = props.zIndex,
		}),
	})
end

local function trim(props: ToonRarityFrameProps): React.ReactNode
	local shade = UIToonConstants.rarity(props.rarity)
	local rim = RIM[props.rarity]
	local nodes: { [string]: React.ReactNode } = {}
	if rim > 0 then
		nodes.rim = e("Frame", {
			Position = UDim2.fromOffset(rim, rim),
			Size = UDim2.new(1, -2 * rim, 1, -2 * rim),
			BackgroundTransparency = 1,
			ZIndex = props.zIndex,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, math.max(0, props.radius - rim)) }),
			stroke = e("UIStroke", {
				Color = shade.hi,
				Thickness = rim,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}, {
				gradient = e("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(shade.hi, shade.base),
				}),
			}),
		})
	end
	if props.rarity == "legendary" then
		nodes.sparkles = e(ToonSparkle, {
			spots = {
				{ position = UDim2.fromOffset(18, 22), size = 30 },
				{ position = UDim2.new(1, -20, 0, 60), size = 22 },
				{ position = UDim2.new(0, 26, 0.55, 0), size = 18 },
			},
			zIndex = props.zIndex,
		})
	elseif props.rarity == "odd" then
		nodes.goo = e(ToonGoo, {
			kind = "cap",
			width = props.width,
			radius = props.radius,
			scale = 0.55,
			zIndex = props.zIndex,
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
	}, nodes)
end

local function ToonRarityFrame(props: ToonRarityFrameProps): React.ReactNode
	return if props.part == "halo" then halo(props) else trim(props)
end

return ToonRarityFrame
