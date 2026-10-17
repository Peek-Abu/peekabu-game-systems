--!strict
--[=[
	ToonIcon: a rendered icon (the kit's 256 px renders, 5 px ink outline baked in) with its hard drop: a second copy of
	the same image tinted ink and offset down, never baked into the PNG. `icon` names a kit icon (UIAssets.toonIcons);
	`image` takes any other image id (a photo cut-out). `greyed` desaturates it for a disabled or locked state.
	Usually placed to break its slot's or panel's edge. Presentational (exempt; story in ToonIcon.story).

	@class ToonIcon
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

export type ToonIconProps = {
	icon: UIAssets.ToonIcon?,
	image: string?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	rotation: number?,
	-- The hard drop's offset in px (default 5; 0 draws none).
	drop: number?,
	greyed: boolean?,
	transparency: (number | React.Binding<number>)?,
	zIndex: number?,
	layoutOrder: number?,
}

local GREY = Color3.fromRGB(150, 146, 160)

local function ToonIcon(props: ToonIconProps): React.ReactNode
	local image = if props.icon ~= nil then UIAssets.toonIcons[props.icon] else props.image or ""
	local drop = props.drop or 5
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		Rotation = props.rotation,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
	}, {
		drop = if drop > 0
			then e("ImageLabel", {
				Position = UDim2.fromOffset(0, drop),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = image,
				ImageColor3 = UIToonConstants.COLOR.ink,
				ImageTransparency = props.transparency,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 1,
			})
			else nil,
		art = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = image,
			ImageColor3 = if props.greyed then GREY else Color3.new(1, 1, 1),
			ImageTransparency = props.transparency,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}),
	})
end

return ToonIcon
