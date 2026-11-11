--!strict
--[=[
	DepotMapCards: the truck's two big map cards, OFFICE and SCHOOL (the School map plan), drawn above the Next shift
	card on a hosted truck (DepotNextShiftCard places them). Each card is a kit tile (ToonButton `tile`): a rendered
	icon breaking its top edge (the office's monitor, the school's globe: placeholders from the kit until a School
	render exists) over the map's word. The truck's pick is lifted in the selected ring and the other recedes; above
	them a cream pill says "Pick a map!" to the host or "The host picks the map." to everyone else. Only the host's
	taps reach `onPick` (the server checks again). What it shows is DepotPadViewModel.maps. Presentational (exempt).

	@class DepotMapCards
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

export type DepotMapCardsProps = {
	view: DepotPadViewModel.MapPickView,
	phone: boolean,
	-- Where the block's bottom-right corner sits in its parent.
	position: UDim2,
	onPick: (map: ShiftTypes.MapId) -> (),
}

type Look = { icon: UIAssets.ToonIcon, variant: ToonStyleViewModel.Variant }

local LOOK: { [ShiftTypes.MapId]: Look } = {
	office = { icon = "monitor", variant = "sky" },
	school = { icon = "globe", variant = "gleam" },
}

-- A card's side, the gap between cards and the pill's height, per layout (phone tiles match the hub's 66 px tiles).
local DESKTOP = { side = 124, gap = 12, pill = 34, text = 26, line = 18 }
local PHONE = { side = 66, gap = 8, pill = 24, text = 14, line = 12 }

-- The block's size (cards side by side under the pill), for the parent to stack it.
local function size(phone: boolean): Vector2
	local g = if phone then PHONE else DESKTOP
	return Vector2.new(g.side * 2 + g.gap, g.pill + 8 + g.side)
end

local function DepotMapCards(props: DepotMapCardsProps): React.ReactNode
	local g = if props.phone then PHONE else DESKTOP
	local view = props.view
	local box = size(props.phone)
	local children: { [string]: React.ReactNode } = {
		line = e(ToonPill, {
			text = view.line,
			hue = "cream",
			textSize = g.line,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.fromScale(0.5, 0),
			size = UDim2.fromOffset(box.X, g.pill),
		}),
	}
	for index, card in view.cards do
		local map: ShiftTypes.MapId = card.map
		local look = LOOK[map]
		children[`card{index}`] = e(ToonButton, {
			variant = look.variant,
			layout = "tile",
			icon = look.icon,
			text = card.label,
			textSize = g.text,
			small = props.phone,
			radius = if props.phone then 16 else 22,
			position = UDim2.fromOffset((index - 1) * (g.side + g.gap), g.pill + 8),
			size = UDim2.fromOffset(g.side, g.side),
			selected = card.selected,
			receded = not card.selected,
			-- The crew sees the host's pick; the other card greys out for them (a tap answers with the error sound).
			disabled = not view.canPick and not card.selected,
			onActivated = function()
				if view.canPick and not card.selected then
					props.onPick(map)
				end
			end,
			layoutOrder = index,
		})
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = props.position,
		Size = UDim2.fromOffset(box.X, box.Y),
		BackgroundTransparency = 1,
	}, children)
end

return {
	render = DepotMapCards,
	size = size,
}
