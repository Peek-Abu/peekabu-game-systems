--!strict
--[=[
	ShiftCarryPanel: the carry panel (Figma 1a-1c "Carry", 640x196, bottom left): Figma's dark tray for live state (no
	paper), with HANDS (an art slot, the item's name, its value and its traits, red when FRAGILE), POCKETS (two slots,
	the empty one dashed) and CANISTER (three cells filled up to the canister, "2 / 3", "full = dust bag").
	On phone (Figma 1d/1e "Carry (compact)", 224x92 at the top right, since the thumbstick owns the bottom left): the
	hands slot (HANDS, the name, the short value in red when fragile), two 56 px pocket slots, and CAN with three small
	cells and "2/3". Presentational: it draws the HudView it is given. The desktop "Q pocket" caption names the pocket
	action's live key (`pocketKey`, from ShiftHudViewModel.pocketKey; Q when not given).

	@class ShiftCarryPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement

export type ShiftCarryPanelProps = {
	view: ShiftHudViewModel.HudView,
	layout: UIPaperConstants.Layout,
	pocketKey: string?,
	-- The desktop panel's left edge (ShiftHudViewModel.carryLeft); the corner inset when nil.
	left: number?,
}

local COLOR = UIPaperConstants.COLOR
local TEXT = UIPaperConstants.TEXT.desktop
local PHONE_TEXT = UIPaperConstants.TEXT.phone
-- Figma 1a "Carry": (48, 836) 640x196 on a 1080 screen, i.e. 48 px in from the left and the bottom.
local SLOT = 76
local DASH = 6
local GAP = 4
local CELL_WIDTH = 30
local CELL_HEIGHT = 92
local CELL_STEP = 40
-- Caption grey (Figma #AEB3BA): the fluorescent white, faded.
local CAPTION_TRANSPARENCY = 0.3

-- A dashed outline (Roblox strokes are solid): short Frames along each edge of a `size` square.
local function dashedOutline(size: number, color: Color3): React.ReactNode
	local dashes: { [string]: React.ReactNode } = {}
	local count = math.floor((size + GAP) / (DASH + GAP))
	for index = 0, count - 1 do
		local along = index * (DASH + GAP)
		dashes[`top{index}`] = e("Frame", {
			Position = UDim2.fromOffset(along, 0),
			Size = UDim2.fromOffset(DASH, 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		})
		dashes[`bottom{index}`] = e("Frame", {
			Position = UDim2.fromOffset(along, size - 1),
			Size = UDim2.fromOffset(DASH, 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		})
		dashes[`left{index}`] = e("Frame", {
			Position = UDim2.fromOffset(0, along),
			Size = UDim2.fromOffset(1, DASH),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		})
		dashes[`right{index}`] = e("Frame", {
			Position = UDim2.fromOffset(size - 1, along),
			Size = UDim2.fromOffset(1, DASH),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, dashes)
end

local function title(text: string, x: number): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = "heading",
		size = TEXT.label,
		color = COLOR.fluorescent,
		position = UDim2.fromOffset(x, 12),
		frame = UDim2.fromOffset(160, 30),
		autoSize = false,
		wrapped = false,
	})
end

local function caption(text: string, x: number, y: number): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = "body",
		size = TEXT.hint,
		color = COLOR.fluorescent,
		transparency = CAPTION_TRANSPARENCY,
		position = UDim2.fromOffset(x, y),
		frame = UDim2.fromOffset(180, 22),
		autoSize = false,
		wrapped = false,
	})
end

local function hands(view: ShiftHudViewModel.HudView): React.ReactNode
	local held = view.hands
	local children: { [string]: React.ReactNode } = {
		stroke = e("UIStroke", {
			Color = COLOR.fluorescent,
			Thickness = 1,
			Transparency = if held ~= nil then 0.4 else 0.8,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		-- The item art lands in the art pass (asset slots stay PENDING); until then a dashed "art" slot.
		art = e("Frame", {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(72, 72),
			BackgroundColor3 = COLOR.night,
			BorderSizePixel = 0,
		}, {
			outline = dashedOutline(72, COLOR.slotEmpty),
			label = e(PaperLabel, {
				text = "art",
				role = "body",
				size = TEXT.hint,
				color = COLOR.slotEmpty,
				align = "center",
				frame = UDim2.fromScale(1, 1),
				autoSize = false,
			}),
		}),
	}
	if held == nil then
		children.name = e(PaperLabel, {
			text = "—",
			role = "heading",
			size = 28,
			color = COLOR.slotEmpty,
			position = UDim2.fromOffset(96, 10),
			frame = UDim2.fromOffset(94, 40),
			autoSize = false,
		})
	else
		children.name = e("Frame", {
			Position = UDim2.fromOffset(96, 10),
			Size = UDim2.fromOffset(98, 40),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
		}, {
			label = e(PaperLabel, {
				text = held.name,
				role = "heading",
				size = 28,
				color = COLOR.fluorescent,
				frame = UDim2.fromScale(1, 1),
				autoSize = false,
				wrapped = false,
			}),
		})
		children.value = e(PaperLabel, {
			text = held.value,
			role = "number",
			size = 24,
			color = COLOR.monitor,
			position = UDim2.fromOffset(96, 50),
			frame = UDim2.fromOffset(98, 36),
			autoSize = false,
		})
		children.traits = e(PaperLabel, {
			text = held.traits,
			role = "body",
			size = TEXT.label,
			color = if held.fragile then COLOR.exitRed else COLOR.fluorescent,
			position = UDim2.fromOffset(12, 98),
			frame = UDim2.fromOffset(180, 24),
			autoSize = false,
			wrapped = false,
		})
	end
	return e("Frame", {
		Position = UDim2.fromOffset(20, 44),
		Size = UDim2.fromOffset(200, 136),
		BackgroundColor3 = COLOR.office,
		BorderSizePixel = 0,
	}, children)
end

local function pocket(index: number, item: ShiftHudViewModel.PocketView): React.ReactNode
	return e("Frame", {
		Position = UDim2.fromOffset(244 + (index - 1) * 88, 44),
		Size = UDim2.fromOffset(SLOT, SLOT),
		BackgroundColor3 = COLOR.night,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, {
		outline = if item.empty then dashedOutline(SLOT, COLOR.slotEmpty) else nil,
		stroke = if item.empty
			then nil
			else e("UIStroke", {
				Color = COLOR.fluorescent,
				Thickness = 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		label = e(PaperLabel, {
			text = item.name,
			role = "medium",
			size = TEXT.label,
			color = if item.empty then COLOR.slotEmpty else COLOR.fluorescent,
			align = "center",
			position = UDim2.fromOffset(4, 0),
			frame = UDim2.new(1, -8, 1, 0),
			autoSize = false,
		}),
	})
end

local function canister(view: ShiftHudViewModel.HudView): React.ReactNode
	local cells: { [string]: React.ReactNode } = {}
	for index = 1, view.canisterMax do
		cells[`cell{index}`] = e("Frame", {
			Position = UDim2.fromOffset((index - 1) * CELL_STEP, 0),
			Size = UDim2.fromOffset(CELL_WIDTH, CELL_HEIGHT),
			BackgroundColor3 = if index <= view.canister then COLOR.fluorGlow else COLOR.office,
			BorderSizePixel = 0,
		}, {
			stroke = e("UIStroke", {
				Color = COLOR.fluorescent,
				Thickness = 1,
				Transparency = 0.7,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
	end
	return e("Frame", {
		Position = UDim2.fromOffset(440, 44),
		Size = UDim2.fromOffset(CELL_STEP * view.canisterMax, CELL_HEIGHT),
		BackgroundTransparency = 1,
	}, cells)
end

-- Figma 1d "Carry (compact)": (572, 66) 224x92 on 844, i.e. 48 px in from the right (the phone safe area).
local PHONE_RIGHT = UIPaperConstants.SAFE.phone.right
local PHONE_TOP = 66
local PHONE_SLOT = 56
local PHONE_POCKET_LEFT = 108
local PHONE_CELL = 14
local PHONE_CELL_STEP = 18

local function phoneText(
	text: string,
	role: PaperLabel.Role,
	size: number,
	color: Color3,
	position: UDim2,
	frame: UDim2
): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = role,
		size = size,
		color = color,
		position = position,
		frame = frame,
		autoSize = false,
		wrapped = false,
	})
end

-- A grey 14 px caption (Figma #AEB3BA: the fluorescent white, faded).
local function phoneCaption(text: string, position: UDim2, frame: UDim2): React.ReactNode
	return e(PaperLabel, {
		text = text,
		role = "heading",
		size = PHONE_TEXT.label,
		color = COLOR.fluorescent,
		transparency = CAPTION_TRANSPARENCY,
		position = position,
		frame = frame,
		autoSize = false,
		wrapped = false,
	})
end

local function phoneHands(view: ShiftHudViewModel.HudView): React.ReactNode
	local held = view.hands
	return e("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(92, 76),
		BackgroundColor3 = COLOR.office,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		stroke = e("UIStroke", {
			Color = COLOR.fluorescent,
			Thickness = 2,
			Transparency = 0.1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		title = phoneCaption("HANDS", UDim2.fromOffset(8, 4), UDim2.fromOffset(76, 21)),
		name = phoneText(
			if held ~= nil then held.name else "—",
			"heading",
			PHONE_TEXT.value,
			if held ~= nil then COLOR.fluorescent else COLOR.slotEmpty,
			UDim2.fromOffset(8, 24),
			UDim2.fromOffset(76, 27)
		),
		short = if held ~= nil
			then phoneText(
				held.short,
				"medium",
				PHONE_TEXT.label,
				if held.fragile then COLOR.exitRed else COLOR.fluorescent,
				UDim2.fromOffset(8, 50),
				UDim2.fromOffset(76, 21)
			)
			else nil,
	})
end

local function phonePocket(index: number, item: ShiftHudViewModel.PocketView): React.ReactNode
	return e("Frame", {
		Position = UDim2.fromOffset(PHONE_POCKET_LEFT + (index - 1) * PHONE_SLOT, 8),
		Size = UDim2.fromOffset(PHONE_SLOT, PHONE_SLOT),
		BackgroundColor3 = COLOR.night,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		stroke = e("UIStroke", {
			Color = COLOR.fluorescent,
			Thickness = 2,
			Transparency = if item.empty then 0.65 else 0.1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		label = e(PaperLabel, {
			text = item.name,
			role = "medium",
			size = PHONE_TEXT.body,
			color = if item.empty then COLOR.slotEmpty else COLOR.fluorescent,
			align = "center",
			position = UDim2.fromOffset(4, 0),
			frame = UDim2.new(1, -8, 1, 0),
			autoSize = false,
		}),
	})
end

local function phonePanel(view: ShiftHudViewModel.HudView): React.ReactNode
	local canLeft = PHONE_POCKET_LEFT + 32
	local children: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		hands = phoneHands(view),
		can = phoneCaption("CAN", UDim2.fromOffset(PHONE_POCKET_LEFT, 64), UDim2.fromOffset(30, 21)),
		count = phoneText(
			`{view.canister}/{view.canisterMax}`,
			"heading",
			PHONE_TEXT.label,
			COLOR.fluorescent,
			UDim2.fromOffset(canLeft + PHONE_CELL_STEP * view.canisterMax + 2, 64),
			UDim2.fromOffset(30, 21)
		),
	}
	for index, item in view.pockets do
		children[`pocket{index}`] = phonePocket(index, item)
	end
	for index = 1, view.canisterMax do
		children[`cell{index}`] = e("Frame", {
			Position = UDim2.fromOffset(canLeft + (index - 1) * PHONE_CELL_STEP, 68),
			Size = UDim2.fromOffset(PHONE_CELL, PHONE_CELL),
			BackgroundColor3 = if index <= view.canister then COLOR.fluorGlow else COLOR.office,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 2) }),
			stroke = e("UIStroke", {
				Color = COLOR.fluorescent,
				Thickness = 1,
				Transparency = 0.4,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PHONE_RIGHT, 0, PHONE_TOP),
		Size = UDim2.fromOffset(224, 92),
		BackgroundColor3 = COLOR.night,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}, children)
end

local function ShiftCarryPanel(props: ShiftCarryPanelProps): React.ReactNode
	local view = props.view
	if props.layout == "phone" then
		return phonePanel(view)
	end
	local children: { [string]: React.ReactNode } = {
		stroke = e("UIStroke", {
			Color = COLOR.fluorescent,
			Thickness = 1,
			Transparency = 0.7,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		handsTitle = title("HANDS", 20),
		hands = hands(view),
		pocketsTitle = title("POCKETS", 244),
		pocketCaption = caption(`{props.pocketKey or "Q"} pocket`, 244, 132),
		canisterTitle = title("CANISTER", 440),
		canister = canister(view),
		count = e(PaperLabel, {
			text = `{view.canister} / {view.canisterMax}`,
			role = "number",
			size = 26,
			color = COLOR.fluorescent,
			position = UDim2.fromOffset(440 + CELL_STEP * view.canisterMax, 72),
			frame = UDim2.fromOffset(70, 39),
			autoSize = false,
			wrapped = false,
		}),
		canisterCaption = caption("full = dust bag", 440, 148),
	}
	for index, item in view.pockets do
		children[`pocket{index}`] = pocket(index, item)
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, props.left or UIPaperConstants.HUD.CARRY_INSET, 1, -UIPaperConstants.HUD.CARRY_INSET),
		Size = UDim2.fromOffset(UIPaperConstants.HUD.CARRY_WIDTH, UIPaperConstants.HUD.CARRY_HEIGHT),
		BackgroundColor3 = COLOR.night,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, children)
end

return ShiftCarryPanel
