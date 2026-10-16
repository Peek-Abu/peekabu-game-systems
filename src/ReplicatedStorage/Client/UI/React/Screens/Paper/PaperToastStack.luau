--!strict
--[=[
	PaperToastStack: Cleanup Crew's toasts on paper (Figma 1f). Taped sticky notes stack top-right (phone: centre-top,
	250 px wide), newest on top, and stamp-style toasts thunk in big at the centre (shift milestones only). Slips (an
	appraisal: the item over its value) are small sticky slips stacked bottom-right just above the hands and tool cards
	(phone: right side under the tool card, clear of the action arc), newest nearest the corner, drifting in quietly; a
	jackpot slip carries a small red JACKPOT stamp and its value in red. It replaces the base ToastStack
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
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local PaperToastViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperToastViewModel)
local StickyNote = require(ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local usePaperMotion = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperMotion)

local e = React.createElement

export type LayerProps = {
	-- Design-pixel inset; the live widget converts the compact time card clearance from screen pixels.
	top: number?,
	-- Design-pixel insets of the slip stack's corner (desktop: from the bottom-right; phone: from the top-right); the
	-- live widget converts the compact HUD's hands and tool card clearance from screen pixels.
	slipBottom: number?,
	slipRight: number?,
	slipTop: number?,
	view: PaperToastViewModel.ToastView,
	layout: UIPaperConstants.Layout,
}

local COLOR = UIPaperConstants.COLOR
local FONT_SIZE = table.freeze({
	desktop = table.freeze({ title = 20, detail = 26, jackpot = 18 }),
	phone = table.freeze({ title = 13, detail = 16, jackpot = 12 }),
})
local SLIP_WIDTH = table.freeze({ desktop = 250, phone = 140 })
-- A slip drifts in from a little to the right, far shorter than a note's slide: it should be easy to miss.
local SLIP_DRIFT = 40

type SlipProps = {
	slip: PaperToastViewModel.SlipView,
	layout: UIPaperConstants.Layout,
	layoutOrder: number,
}

-- One appraisal slip: a small yellow sticky with a scrap of tape, the item in marker, its value in Oswald.
local function Slip(props: SlipProps): React.ReactNode
	local alpha = usePaperMotion(UIPaperConstants.MOTION.slideSeconds)
	local slip = props.slip
	local phone = props.layout == "phone"
	local sizes = FONT_SIZE[props.layout]
	local width = SLIP_WIDTH[props.layout]
	local pad = if phone then 8 else 14
	local lines: { [string]: React.ReactNode } = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, if phone then 0 else 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, pad),
			PaddingRight = UDim.new(0, pad),
			PaddingTop = UDim.new(0, pad + (if slip.jackpot then sizes.jackpot else 0)),
			PaddingBottom = UDim.new(0, pad),
		}),
		title = e(PaperLabel, {
			text = slip.title,
			role = "marker",
			size = sizes.title,
			color = COLOR.ink,
			layoutOrder = 1,
		}),
	}
	local detail = slip.detail
	if detail ~= nil then
		lines.detail = e(PaperLabel, {
			text = detail,
			role = "number",
			size = sizes.detail,
			color = if slip.jackpot then COLOR.inkRed else COLOR.ink,
			layoutOrder = 2,
		})
	end
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		note = e("Frame", {
			Position = alpha:map(function(value: number): UDim2
				return UDim2.fromOffset(SLIP_DRIFT * (1 - value), 0)
			end),
			Size = UDim2.fromOffset(width, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Rotation = slip.tilt,
			BackgroundColor3 = COLOR.sticky,
			BorderSizePixel = 0,
		}, {
			texture = e(PaperTexture, { paper = COLOR.sticky }),
			tape = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromOffset(if phone then 32 else 54, if phone then 8 else 14),
				BackgroundColor3 = COLOR.cream,
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				ZIndex = 3,
			}),
			jackpot = if slip.jackpot
				then e(PaperStamp, {
					text = "JACKPOT",
					size = sizes.jackpot,
					tilt = UIPaperConstants.STAMP_TILT,
					anchor = Vector2.new(0, 0),
					position = UDim2.fromOffset(pad - 4, if phone then 3 else 6),
				})
				else nil,
			body = e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, lines),
		}),
	})
end

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
			Position = if phone then UDim2.new(0.5, 0, 0, 86) else UDim2.new(1, -60, 0, props.top or 80),
			Size = UDim2.fromOffset(if phone then 250 else 340, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, notes),
	}
	if #view.slips > 0 then
		local slips: { [string]: React.ReactNode } = {
			list = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = if phone then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, if phone then 6 else 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for order, slip in view.slips do
			slips[`slip{slip.id}`] = e(Slip, {
				slip = slip,
				layout = props.layout,
				-- Newest nearest the corner: at the bottom of the desktop stack, at the top of the phone one.
				layoutOrder = if phone then order else -order,
			})
		end
		children.slips = e("Frame", {
			AnchorPoint = if phone then Vector2.new(1, 0) else Vector2.new(1, 1),
			Position = if phone
				then UDim2.new(1, -(props.slipRight or 12), 0, props.slipTop or 172)
				else UDim2.new(1, -(props.slipRight or 24), 1, -(props.slipBottom or 250)),
			Size = UDim2.fromOffset(SLIP_WIDTH[props.layout], 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, slips)
	end
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

-- Screen px the slips keep clear of the compact HUD (see Widget), and the phone's stack limit (two fit above the Jump
-- button).
local SLIP_CLEAR_DESKTOP = 250
local SLIP_CLEAR_PHONE = 172
local SLIP_LIMIT_PHONE = 2

local function Widget(): React.ReactNode
	local toasts = ReactCharm.useAtom(ToastStore.toasts)
	local scaring = ReactCharm.useAtom(OccupantCatchStore.scaring)
	-- Drawn scaled to the window on desktop, with the rest of the HUD (PaperHudFrame).
	local hudScale = usePaperHudScale()
	local layout: UIPaperConstants.Layout = hudScale.layout
	-- Typed up front: inline in e() the Layout literal union widens to string.
	local scale = hudScale.scale
	local layerProps: LayerProps = {
		view = PaperToastViewModel.layout(
			toasts,
			PaperToastViewModel.MAX_NOTES,
			if layout == "phone" then SLIP_LIMIT_PHONE else PaperToastViewModel.MAX_SLIPS
		),
		layout = layout,
		top = if layout == "desktop" then 128 / scale else nil,
		-- The compact HUD (ShiftCompactHudPanel) draws in screen px: on desktop nothing of it on the right reaches
		-- SLIP_CLEAR_DESKTOP px up from the bottom-right (its hotbar is centred); on phone the time card and the stamina
		-- slip end above SLIP_CLEAR_PHONE px down. The slips sit just past them, converted to this frame's design px.
		slipBottom = if layout == "desktop" then SLIP_CLEAR_DESKTOP / scale else nil,
		slipRight = (if layout == "desktop" then 24 else 12) / scale,
		slipTop = if layout == "phone" then SLIP_CLEAR_PHONE / scale else nil,
	}
	-- Figma 4a: no HUD and no text during the scare beat. The layer stays mounted and is hidden with a prop, so the
	-- notes and the stamp do not remount (and replay their entrance) when the beat ends.
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = not scaring,
	}, { frame = e(PaperHudFrame, { scale = hudScale.scale, children = { layer = e(Layer, layerProps) } }) })
end

return {
	Widget = Widget,
	Layer = Layer,
}
