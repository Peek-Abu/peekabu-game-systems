--!strict
--[=[
	DepotPlaceButton: the truck's PLACE button (p1-places-menu; it replaced the two small OFFICE / SCHOOL map cards),
	drawn above the Next shift card on a hosted truck (DepotNextShiftCard places it). One kit tile (ToonButton `tile`):
	the place's render breaking its top edge (the office's monitor, the school's globe) over the place's word, lifted
	in the selected ring. Above it a cream pill says "Tap to pick a place!" to the host or "The host picks the place."
	to everyone else. Anyone's tap opens the places menu (`onOpen`), where the host picks and anyone can look or unlock
	a place. What it shows is DepotPadViewModel.place. Presentational (exempt).

	@class DepotPlaceButton
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local DepotPadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonPill = require(Toon.ToonPill)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)

local e = React.createElement

export type DepotPlaceButtonProps = {
	view: DepotPadViewModel.PlaceButtonView,
	phone: boolean,
	-- Where the block's bottom-right corner sits in its parent.
	position: UDim2,
	onOpen: () -> (),
}

type Look = { icon: UIAssets.ToonIcon, variant: ToonStyleViewModel.Variant }

local LOOK: { [ShiftTypes.MapId]: Look } = {
	office = { icon = "monitor", variant = "sky" },
	school = { icon = "globe", variant = "gleam" },
}

-- The tile's width and height, and the pill's width and height, per layout (phone tiles match the hub's 66 px
-- tiles). The pill is wider than the tile so its line never clips (play check 11-13: "TAP TO PICK A").
local DESKTOP = { width = 200, side = 124, pillWidth = 300, pill = 34, text = 26, line = 18 }
local PHONE = { width = 110, side = 66, pillWidth = 190, pill = 24, text = 14, line = 12 }

-- The block's size (the tile under the pill), for the parent to stack it.
local function size(phone: boolean): Vector2
	local g = if phone then PHONE else DESKTOP
	return Vector2.new(math.max(g.width, g.pillWidth), g.pill + 8 + g.side)
end

local function DepotPlaceButton(props: DepotPlaceButtonProps): React.ReactNode
	local g = if props.phone then PHONE else DESKTOP
	local view = props.view
	local box = size(props.phone)
	local look = LOOK[view.map]
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = props.position,
		Size = UDim2.fromOffset(box.X, box.Y),
		BackgroundTransparency = 1,
	}, {
		line = e(ToonPill, {
			text = view.line,
			hue = "cream",
			textSize = g.line,
			anchor = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
			size = UDim2.fromOffset(g.pillWidth, g.pill),
		}),
		tile = e(ToonButton, {
			variant = look.variant,
			layout = "tile",
			icon = look.icon,
			text = view.label,
			textSize = g.text,
			small = props.phone,
			radius = if props.phone then 16 else 22,
			position = UDim2.fromOffset(box.X - g.width, g.pill + 8),
			size = UDim2.fromOffset(g.width, g.side),
			selected = true,
			onActivated = props.onOpen,
		}),
	})
end

return {
	render = DepotPlaceButton,
	size = size,
}
