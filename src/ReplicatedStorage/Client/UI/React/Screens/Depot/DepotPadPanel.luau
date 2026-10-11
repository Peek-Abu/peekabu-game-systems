--!strict
--[=[
	DepotPadPanel: the truck's queue card on paper (Figma 3a desktop, 3b phone). Desktop: a cream sheet with a red band
	("TRUCK 2 — HARLOW & FINCH JOB"), the big CREW count, a card per seat (open seats dashed, yours in sticky yellow),
	DEPARTS IN with the timer (LEAVING stamped once the truck goes), the green DEPART NOW button and the leave hint,
	bottom-centre. Phone: a compact strip across the top safe area, and DEPART NOW with its hint just left of the
	engine's Jump button (`jump`, from ShiftHudViewModel.arcFor), clear of the thumbstick zone. Presentational:
	which seats show and what they say is the specced DepotPadViewModel.

	@class DepotPadPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotPadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadViewModel)
local PaperButton = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperButton)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement
local COLOR = UIPaperConstants.COLOR

export type DepotPadPanelProps = {
	view: DepotPadViewModel.PadView,
	layout: UIPaperConstants.Layout,
	onDepart: () -> (),
	-- The engine's Jump button (offsets from the bottom-right corner); the phone button sits left of it.
	jump: ShiftHudViewModel.ArcSpot?,
}

local DASH = 8
local GAP = 6
local DASH_THICKNESS = 3
-- Space kept between the phone button and the Jump button, and the button's foot above the screen bottom.
local JUMP_GAP = 16
local PHONE_BOTTOM = 20
local PHONE_BUTTON_HEIGHT = 56
local PHONE_CARD_WIDTH = 420

-- An outline of dashes around a side x side box (a Frame cannot dash its stroke).
local function dashedBorder(side: number): { [string]: React.ReactNode }
	local dashes: { [string]: React.ReactNode } = {}
	local function dash(key: string, x: number, y: number, w: number, h: number)
		dashes[key] = e("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = COLOR.slotEmpty,
			BorderSizePixel = 0,
		})
	end
	local step = DASH + GAP
	for index = 0, math.floor((side - DASH) / step) do
		dash(`top{index}`, index * step, 0, DASH, DASH_THICKNESS)
		dash(`bottom{index}`, index * step, side - DASH_THICKNESS, DASH, DASH_THICKNESS)
		dash(`left{index}`, 0, index * step, DASH_THICKNESS, DASH)
		dash(`right{index}`, side - DASH_THICKNESS, index * step, DASH_THICKNESS, DASH)
	end
	return dashes
end

-- One seat: a dark card with the name (open: dashed outline; yours: sticky yellow name). `side` is the square's edge;
-- `named` writes the name inside it (the phone lists names on one line instead and marks yours with a yellow square).
local function seat(
	slot: DepotPadViewModel.SlotView,
	side: number,
	x: number,
	y: number,
	named: boolean
): React.ReactNode
	local children: { [string]: React.ReactNode } = {}
	if slot.open then
		children.dashes = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, dashedBorder(side))
	else
		children.corner = e("UICorner", { CornerRadius = UDim.new(0, 4) })
	end
	if named then
		children.name = e(PaperLabel, {
			text = slot.name,
			role = "body",
			size = 16,
			color = if slot.open then COLOR.slotEmpty elseif slot.you then COLOR.sticky else COLOR.cream,
			align = "center",
			frame = UDim2.fromScale(1, 1),
			autoSize = false,
		})
	end
	return e("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = if slot.you and not named then COLOR.sticky else COLOR.office,
		BackgroundTransparency = if slot.open then 1 else 0,
		BorderSizePixel = 0,
	}, children)
end

local function timerOrStamp(
	view: DepotPadViewModel.PadView,
	timerSize: number,
	stampSize: number,
	position: UDim2,
	anchor: Vector2
): React.ReactNode
	if view.departing then
		return e(PaperStamp, { text = "LEAVING", size = stampSize, position = position, anchor = anchor })
	end
	local departsIn = view.departsIn
	if departsIn == nil then
		return nil
	end
	return e(PaperLabel, {
		text = departsIn,
		role = "timer",
		size = timerSize,
		fit = true,
		position = position,
		anchor = anchor,
	})
end

local function desktop(props: DepotPadPanelProps): React.ReactNode
	local view = props.view
	-- Positions are Figma 3a's, less the 26 px band (the sheet's content starts under it).
	local children: { [string]: React.ReactNode } = {
		crew = e(PaperLabel, {
			text = "CREW",
			role = "body",
			size = 20,
			fit = true,
			position = UDim2.fromOffset(28, 32),
		}),
		count = e(PaperLabel, {
			text = view.count,
			role = "number",
			size = 64,
			fit = true,
			position = UDim2.fromOffset(28, 54),
		}),
		button = e(PaperButton, {
			text = "DEPART NOW",
			variant = "go",
			size = UDim2.fromOffset(226, 76),
			textSize = 26,
			disabled = view.departing,
			onActivated = props.onDepart,
			position = UDim2.fromOffset(28, 142),
			onPaper = true,
		}),
		hint = e(PaperLabel, {
			text = view.hint,
			role = "body",
			size = 20,
			frame = UDim2.fromOffset(440, 40),
			autoSize = false,
			position = UDim2.fromOffset(290, 158),
		}),
		timer = timerOrStamp(view, 56, 30, UDim2.fromOffset(576, 54), Vector2.new(0, 0)),
	}
	if not view.departing then
		children.departsLabel = e(PaperLabel, {
			text = "DEPARTS IN",
			role = "body",
			size = 20,
			fit = true,
			position = UDim2.fromOffset(580, 32),
		})
	end
	for index, slot in view.slots do
		children[`seat{index}`] = seat(slot, 80, 200 + (index - 1) * 92, 44, true)
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		-- Figma 3a: the card's foot is 48 px above the bottom edge (y 776 + 256 of 1080).
		Position = UDim2.new(0.5, 0, 1, -48),
		Size = UDim2.fromOffset(760, 256),
		BackgroundTransparency = 1,
	}, {
		sheet = e(PaperSheet, {
			size = UDim2.fromScale(1, 1),
			paper = COLOR.cream,
			band = view.title,
			bandColor = COLOR.stamp,
			padding = 0,
			children = children,
		}),
	})
end

local function phone(props: DepotPadPanelProps): React.ReactNode
	local view = props.view
	local jump = props.jump or ShiftHudViewModel.arcFor(0).jump
	-- The button's right edge sits JUMP_GAP left of the Jump button's left edge (jump.x is negative: from the right).
	local buttonRight = jump.x - JUMP_GAP
	local children: { [string]: React.ReactNode } = {
		bar = e("Frame", {
			Size = UDim2.new(0, 8, 1, 0),
			BackgroundColor3 = COLOR.stamp,
			BorderSizePixel = 0,
		}),
		title = e(PaperLabel, {
			text = view.title,
			role = "heading",
			size = 15,
			fit = true,
			position = UDim2.fromOffset(22, 8),
		}),
		count = e(PaperLabel, {
			text = view.count,
			role = "number",
			size = 40,
			fit = true,
			position = UDim2.fromOffset(22, 28),
		}),
		names = e(PaperLabel, {
			text = view.names,
			role = "body",
			size = 14,
			frame = UDim2.fromOffset(150, 16),
			autoSize = false,
			wrapped = false,
			position = UDim2.fromOffset(130, 78),
		}),
		timer = timerOrStamp(view, 36, 22, UDim2.new(1, -16, 0, 30), Vector2.new(1, 0)),
	}
	if not view.departing then
		children.departsLabel = e(PaperLabel, {
			text = "DEPARTS IN",
			role = "body",
			size = 15,
			fit = true,
			position = UDim2.new(1, -16, 0, 8),
			anchor = Vector2.new(1, 0),
		})
	end
	for index, slot in view.slots do
		children[`seat{index}`] = seat(slot, 32, 130 + (index - 1) * 40, 40, false)
	end
	return e(React.Fragment, nil, {
		card = e("Frame", {
			-- Figma 3b: a fixed 420x104 card centred at the top, at the top safe margin.
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, UIPaperConstants.SAFE.phone.top),
			Size = UDim2.fromOffset(PHONE_CARD_WIDTH, 104),
			BackgroundTransparency = 1,
		}, {
			sheet = e(PaperSheet, {
				size = UDim2.fromScale(1, 1),
				paper = COLOR.cream,
				padding = 0,
				children = children,
			}),
		}),
		-- The hint is cream text over the world, so it sits on a small dark plate.
		hint = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, buttonRight, 1, -(PHONE_BOTTOM + PHONE_BUTTON_HEIGHT + 8)),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = COLOR.night,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
			text = e(PaperLabel, {
				text = view.hint,
				role = "body",
				size = 14,
				color = COLOR.cream,
				fit = true,
			}),
		}),
		button = e(PaperButton, {
			text = "DEPART NOW",
			variant = "go",
			size = UDim2.fromOffset(240, PHONE_BUTTON_HEIGHT),
			textSize = 22,
			disabled = view.departing,
			onActivated = props.onDepart,
			anchor = Vector2.new(1, 1),
			position = UDim2.new(1, buttonRight, 1, -PHONE_BOTTOM),
		}),
	})
end

local function DepotPadPanel(props: DepotPadPanelProps): React.ReactNode
	if props.layout == "phone" then
		return phone(props)
	end
	return desktop(props)
end

return DepotPadPanel
