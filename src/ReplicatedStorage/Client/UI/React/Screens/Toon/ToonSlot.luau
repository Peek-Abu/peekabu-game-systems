--!strict
--[=[
	ToonSlot: a hotbar slot on the kit's stack (a dark night plate in a shift): the item's render filling and breaking
	the plate, its key number top-left, an optional caption pill at the foot (the vacuum's charge, a valuable's worth
	with the coin), and the states: `selected` lifts it inside the lilac ring, `disabled` greys it, empty shows the
	bare plate. Tapping or clicking calls `onActivated` when given. Presentational (exempt; story in ToonSlot.story;
	the states are specced in ToonStyleViewModel).

	@class ToonSlot
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonIcon = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonIcon)
local ToonPill = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonPill)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local ToonSurface = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSurface)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local useToonPose = require(ReplicatedStorage.Client.UI.React.Screens.Toon.useToonPose)

local e = React.createElement

export type ToonSlotProps = {
	-- Design px (the slot is square).
	side: number,
	position: UDim2?,
	anchor: Vector2?,
	-- The key that selects it ("1").
	hotkey: string?,
	icon: UIAssets.ToonIcon?,
	image: string?,
	caption: string?,
	captionIcon: UIAssets.ToonIcon?,
	captionMeaning: UIToonConstants.Meaning?,
	selected: boolean?,
	disabled: boolean?,
	onActivated: (() -> ())?,
	zIndex: number?,
	layoutOrder: number?,
}

local function ToonSlot(props: ToonSlotProps): React.ReactNode
	local hovered, setHovered = React.useState(false)
	local disabled = props.disabled == true
	local target = ToonStyleViewModel.pose({
		hovered = hovered and props.onActivated ~= nil,
		pressed = false,
		selected = props.selected == true,
		disabled = disabled,
		receded = false,
	})
	local pose = useToonPose(target, UIToonConstants.MOTION.hoverSeconds)
	local side = props.side
	local hasArt = props.icon ~= nil or props.image ~= nil
	local children: { [string]: React.ReactNode } = {}
	if hasArt then
		children.art = e(ToonIcon, {
			icon = props.icon,
			image = props.image,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.46),
			size = UDim2.fromScale(1.0, 1.0),
			drop = 4,
			greyed = disabled,
			zIndex = 2,
		})
	end
	if props.hotkey ~= nil then
		children.key = e(ToonText, {
			text = props.hotkey,
			textSize = math.floor(side * 0.24),
			position = UDim2.fromOffset(6, 2),
			size = UDim2.fromOffset(side * 0.3, side * 0.28),
			zIndex = 4,
		})
	end
	local overlay: { [string]: React.ReactNode } = {}
	if props.caption ~= nil then
		overlay.caption = e(ToonPill, {
			text = props.caption,
			textSize = math.floor(side * 0.2),
			icon = props.captionIcon,
			iconSize = math.floor(side * 0.3),
			meaning = props.captionMeaning,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 1),
			size = UDim2.fromOffset(side * 0.74, side * 0.28),
			zIndex = 6,
		})
	end
	local hue: UIToonConstants.Hue = if disabled then "steel" else "night"
	local surface = e(ToonSurface, {
		hue = hue,
		size = UDim2.fromScale(1, 1),
		radius = math.floor(side * 0.22),
		pose = pose,
		pattern = "bubbles",
		children = children,
		overlay = overlay,
	})
	local onActivated = props.onActivated
	if onActivated == nil then
		return e("Frame", {
			AnchorPoint = props.anchor,
			Position = props.position,
			Size = UDim2.fromOffset(side, side),
			BackgroundTransparency = 1,
			ZIndex = props.zIndex,
			LayoutOrder = props.layoutOrder,
		}, { surface = surface })
	end
	return e("TextButton", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = UDim2.fromOffset(side, side),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
		[React.Event.Activated] = function()
			if not disabled then
				onActivated()
			end
		end,
	}, { surface = surface })
end

return ToonSlot
