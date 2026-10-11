--!strict
--[=[
	PaperToastStack: Cleanup Crew's toasts on paper (Figma 1f). Taped sticky notes stack top-right (phone: centre-top,
	250 px wide), newest on top, and stamp-style toasts thunk in big at the centre. It replaces the base ToastStack
	(ShiftServiceClient hides that with ToastServiceClient:setDefaultWidget(false)) and draws nothing during the scare
	beat (Figma 4a). Which toasts show, in what order and at what tilt is the specced PaperToastViewModel.

	`Layer` is presentational (view + layout in, so the story never touches a store); `Widget` is the HUD widget that
	reads ToastStore, OccupantCatchStore.scaring and the device layout.

	@class PaperToastStack
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local ToastStore = require(ReplicatedStorage.Client.Features.Toast.State.ToastStore)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local PaperToastViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperToastViewModel)
local StickyNote = require(ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)

local e = React.createElement

export type LayerProps = {
	view: PaperToastViewModel.ToastView,
	layout: UIPaperConstants.Layout,
}

local function Layer(props: LayerProps): React.ReactNode
	local view = props.view
	local text = UIPaperConstants.TEXT[props.layout]
	local phone = props.layout == "phone"
	local notes: { [string]: React.ReactNode } = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, if phone then 14 else 28),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for order, note in view.notes do
		notes[`note{note.id}`] = e(StickyNote, {
			text = note.text,
			width = if phone then 250 else 340,
			size = text.sticky,
			tilt = note.tilt,
			slide = true,
			layoutOrder = order,
		})
	end
	local children: { [string]: React.ReactNode } = {
		notes = e("Frame", {
			-- Desktop: top-right under the top bar (1a/1b at x 1520, y 80). Phone: centre-top (1d at x 304, y 86).
			AnchorPoint = if phone then Vector2.new(0.5, 0) else Vector2.new(1, 0),
			Position = if phone then UDim2.new(0.5, 0, 0, 86) else UDim2.new(1, -60, 0, 80),
			Size = UDim2.fromOffset(if phone then 250 else 340, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, notes),
	}
	local stamp = view.stamp
	if stamp ~= nil then
		-- Keyed by the toast id, so a new stamp remounts and pops again.
		children[`stamp{stamp.id}`] = e(PaperStamp, {
			text = stamp.text,
			size = text.bigStamp,
			tilt = stamp.tilt,
			pop = true,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.38),
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, children)
end

local function Widget(): React.ReactNode
	local toasts = ReactCharm.useAtom(ToastStore.toasts)
	local scaring = ReactCharm.useAtom(OccupantCatchStore.scaring)
	local layout: UIPaperConstants.Layout = usePaperLayout()
	-- Typed up front: inline in e() the Layout literal union widens to string.
	local layerProps: LayerProps = {
		view = PaperToastViewModel.layout(toasts, PaperToastViewModel.MAX_NOTES),
		layout = layout,
	}
	-- Figma 4a: no HUD and no text during the scare beat. The layer stays mounted and is hidden with a prop, so the
	-- notes and the stamp do not remount (and replay their entrance) when the beat ends.
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = not scaring,
	}, { layer = e(Layer, layerProps) })
end

return {
	Widget = Widget,
	Layer = Layer,
}
