--!strict
--[=[
	ToonFlag: a small tilted ribbon with a notched right end, for a word that labels a card or a panel: a rarity
	("LEGENDARY", in the rarity's colour), "New!", "Hot", a skin's name on a Crew card, "Soon". Drawn as the kit's
	ribbon image (9-slice: the notch keeps its shape at any width) tinted in the colour, a hard ink drop under it, and
	display text on top. Sticks out over its parent's edge like a sticker. Presentational (exempt; story in
	ToonFlag.story).

	@class ToonFlag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

export type ToonFlagProps = {
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	-- The colour: a rarity's, else a hue's (default grape).
	rarity: UIToonConstants.Rarity?,
	hue: UIToonConstants.Hue?,
	textSize: number?,
	-- Degrees (default -4: a sticker's lean).
	tilt: number?,
	zIndex: number?,
	layoutOrder: number?,
}

-- The ribbon image's stretchable middle (image px); the notch is the right 56 px.
local SLICE = Rect.new(24, 16, 200, 64)

local function ribbon(color: Color3, offset: number, zIndex: number?): React.ReactNode
	return e("ImageLabel", {
		Position = UDim2.fromOffset(0, offset),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = UIAssets.toon.ribbon,
		ImageColor3 = color,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = SLICE,
		-- The slices are drawn at half size: the image is 2x.
		SliceScale = 0.5,
		ZIndex = zIndex,
	})
end

local function ToonFlag(props: ToonFlagProps): React.ReactNode
	-- The drop under the ribbon, the ribbon, then the word (explicit order: siblings at one ZIndex draw in any order).
	local z = props.zIndex or 1
	local shade = if props.rarity ~= nil
		then UIToonConstants.rarity(props.rarity)
		else UIToonConstants.shade(props.hue or "grape")
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		Rotation = props.tilt or -4,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
	}, {
		drop = ribbon(UIToonConstants.COLOR.ink, 4, z),
		body = ribbon(shade.base, 0, z + 1),
		label = e(ToonText, {
			text = props.text,
			textSize = props.textSize or 20,
			-- Clear of the notch on the right.
			position = UDim2.fromOffset(8, -1),
			size = UDim2.new(1, -30, 1, 0),
			align = "center",
			fit = true,
			zIndex = z + 2,
		}),
	})
end

return ToonFlag
