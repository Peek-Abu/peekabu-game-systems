--!strict
--[=[
	PaperToastStack: Cleanup Crew's toasts in the V1 kit (the shift renders' finds). Notes are cream cards stacked
	top-right (phone: centre-top, 250 px wide), newest on top, and milestone toasts pop in big at the centre as a
	stroked gold title (shift milestones only). Finds (an appraisal: the item and its worth) are small cards stacked
	bottom-right (phone: right side, clear of the action arc), newest nearest the corner, drifting in quietly: the item
	in Fredoka, its worth as a gold number with a Gleam sparkle; a jackpot is a gold card with a coral JACKPOT
	sticker. (The module keeps its name: the toast view model and its registration are unchanged.) It replaces the base ToastStack
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
local PaperToastViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperToastViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonMotionViewModel = require(Toon.ToonMotionViewModel)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)

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

local FONT_SIZE = table.freeze({
	desktop = table.freeze({ title = 20, detail = 30, jackpot = 14 }),
	phone = table.freeze({ title = 13, detail = 18, jackpot = 10 }),
})
local SLIP_WIDTH = table.freeze({ desktop = 280, phone = 150 })
local SLIP_HEIGHT = table.freeze({ desktop = 62, phone = 40 })
-- A slip drifts in from a little to the right, far shorter than a note's slide: it should be easy to miss.
local SLIP_DRIFT = 40

type SlipProps = {
	slip: PaperToastViewModel.SlipView,
	layout: UIPaperConstants.Layout,
	layoutOrder: number,
}

-- One find: a small card with the item and its worth as a gold number, drifting in from the right.
local function Slip(props: SlipProps): React.ReactNode
	local alpha = useToonPlay(UIPaperConstants.MOTION.slideSeconds, 0, nil)
	local slip = props.slip
	local phone = props.layout == "phone"
	local sizes = FONT_SIZE[props.layout]
	local width = SLIP_WIDTH[props.layout]
	local height = SLIP_HEIGHT[props.layout]
	local pad = if phone then 10 else 16
	local detail = slip.detail
	local face: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = slip.title,
			font = "body",
			textSize = sizes.title,
			position = UDim2.fromOffset(pad, 0),
			size = UDim2.new(if detail ~= nil then 0.55 else 1, -pad, 1, 0),
			fit = true,
		}),
	}
	if detail ~= nil then
		face.detail = e(ToonText, {
			text = detail,
			meaning = "gold",
			textSize = sizes.detail,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -pad, 0, 0),
			size = UDim2.new(0.45, -pad, 1, 0),
			align = "right",
			fit = true,
		})
		face.sparkle = e(ToonSparkle, {
			spots = { { position = UDim2.new(1, -pad, 0, 2), size = if phone then 12 else 20 } },
			zIndex = 5,
		})
	end
	local overlay: { [string]: React.ReactNode } = {}
	if slip.jackpot then
		overlay.jackpot = e(ToonPill, {
			text = "JACKPOT",
			hue = "coral",
			textSize = sizes.jackpot,
			tilt = -6,
			position = UDim2.fromOffset(pad - 6, -10),
			size = UDim2.fromOffset(if phone then 64 else 96, if phone then 18 else 26),
			zIndex = 6,
		})
	end
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromOffset(width, height + 8),
		BackgroundTransparency = 1,
	}, {
		drift = e("Frame", {
			Position = alpha:map(function(value: number): UDim2
				return UDim2.fromOffset(SLIP_DRIFT * (1 - value), 0)
			end),
			Size = UDim2.fromOffset(width, height),
			BackgroundTransparency = 1,
		}, {
			card = e(ToonPanel, {
				hue = if slip.jackpot then "gold" else "cream",
				size = Vector2.new(width, height),
				radius = if phone then 14 else 20,
				children = face,
				overlay = overlay,
			}),
		}),
	})
end

-- A note: a cream card with its words in Fredoka (two lines at most).
local function Note(props: { text: string, width: number, size: number, layoutOrder: number }): React.ReactNode
	local face: { [string]: React.ReactNode } = {
		text = e(ToonText, {
			text = props.text,
			font = "body",
			textSize = props.size,
			position = UDim2.fromOffset(16, 6),
			size = UDim2.new(1, -32, 1, -12),
			wrapped = true,
			fit = true,
		}),
	}
	return e(ToonPanel, {
		size = Vector2.new(props.width, math.ceil(props.size * 2.6 + 16)),
		pop = true,
		layoutOrder = props.layoutOrder,
		children = face,
	})
end

-- A milestone: a big stroked gold title that pops in at the centre.
local function Milestone(props: { text: string, size: number, tilt: number }): React.ReactNode
	local alpha = useToonPlay(UIToonConstants.MOTION.popSeconds, 0, nil)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(1200, props.size + 30),
		BackgroundTransparency = 1,
	}, {
		pop = e("UIScale", { Scale = alpha:map(ToonMotionViewModel.pop) }),
		title = e(ToonText, {
			text = props.text,
			meaning = "gold",
			textSize = props.size,
			size = UDim2.fromScale(1, 1),
			align = "center",
			rotation = props.tilt,
			fit = true,
		}),
	})
end

local function Layer(props: LayerProps): React.ReactNode
	local view = props.view
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
		notes[`note{note.id}`] = e(Note, {
			text = note.text,
			width = if phone then 250 else 340,
			size = if phone then 15 else 21,
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
		children[`stamp{stamp.id}`] = e(Milestone, {
			text = stamp.text,
			size = if phone then 56 else 120,
			tilt = -3,
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
