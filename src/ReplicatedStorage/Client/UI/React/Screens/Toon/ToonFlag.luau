--!strict
--[=[
	ToonFlag: a small tilted tag on the kit's stack for a word that labels a card or a panel: a rarity ("EPIC", in the
	rarity's colour), "New!", a skin's name on a Crew card, "Soon". Sticks out over its parent's edge like a sticker.
	Presentational (exempt; story in ToonFlag.story).

	@class ToonFlag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ToonSurface = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSurface)
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

local function ToonFlag(props: ToonFlagProps): React.ReactNode
	local hue: UIToonConstants.Hue = props.hue or "grape"
	local shade = if props.rarity ~= nil then UIToonConstants.rarity(props.rarity) else nil
	local face: { [string]: React.ReactNode } = {
		label = e(ToonText, {
			text = props.text,
			textSize = props.textSize or 20,
			position = UDim2.fromOffset(8, -1),
			size = UDim2.new(1, -16, 1, 0),
			align = "center",
			fit = true,
		}),
	}
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		Rotation = props.tilt or -4,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
	}, {
		surface = e(ToonSurface, {
			hue = hue,
			shade = shade,
			size = UDim2.fromScale(1, 1),
			radius = 8,
			small = true,
			children = face,
		}),
	})
end

return ToonFlag
