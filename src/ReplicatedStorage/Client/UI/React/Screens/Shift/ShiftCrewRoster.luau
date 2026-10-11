--!strict
--[=[
	ShiftCrewRoster: the clipped crew roster card (Figma 35:1100 / 35:1119 / 35:1137, 1a-1c "Crew strip"): a cream sheet
	under a binder clip, "CREW ROSTER · TRUCK 2", and a row per crew member: a drawn tick box (a green tick for crew at
	or in the truck, a red marker "X" when struck, empty otherwise), the name (struck through when caught or not aboard)
	and the status in its ink. No glyph ticks: the tick is two thin Frames. Presentational: the statuses, inks, strikes
	and box states come from ShiftCrewViewModel. On phone (Figma 1d/1e "Crew strip", 232 wide at (50, 174)) the card is a
	clipped cream slip with the view model's two condensed lines in Oswald Medium 15, the trouble line in red ink.

	@class ShiftCrewRoster
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)

local e = React.createElement

export type ShiftCrewRosterProps = {
	roster: ShiftCrewViewModel.RosterView,
	layout: UIPaperConstants.Layout,
}

local COLOR = UIPaperConstants.COLOR
local TEXT = UIPaperConstants.TEXT.desktop
local PHONE_TEXT = UIPaperConstants.TEXT.phone
-- Figma 1a "Crew strip": (52, 330), 350 wide, 46 px of title plus 36 px per row; rows start at y 49.
local LEFT = 52
local TOP = 330
local WIDTH = 350
local HEADER = 46
local ROW = 36
local ROW_TOP = 46
local BOX = 16
local NAME_LEFT = 44
local NAME_WIDTH = 66
local STATUS_LEFT = 116

-- A tick drawn in green ink: a short stroke down to the right, then a long one up to the right.
local function tick(): React.ReactNode
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		short = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(5, 10),
			Size = UDim2.fromOffset(7, 3),
			Rotation = 45,
			BackgroundColor3 = COLOR.inkGreen,
			BorderSizePixel = 0,
		}),
		long = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(12, 3),
			Rotation = -55,
			BackgroundColor3 = COLOR.inkGreen,
			BorderSizePixel = 0,
		}),
	})
end

local function row(index: number, member: ShiftCrewViewModel.MemberView): React.ReactNode
	return e("Frame", {
		Position = UDim2.fromOffset(0, ROW_TOP + (index - 1) * ROW),
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundTransparency = 1,
	}, {
		rule = if index > 1
			then e("Frame", {
				Position = UDim2.fromOffset(16, -1),
				Size = UDim2.new(1, -32, 0, 1),
				BackgroundColor3 = COLOR.manilaDeep,
				BorderSizePixel = 0,
			})
			else nil,
		box = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
			Size = UDim2.fromOffset(BOX, BOX),
			BackgroundTransparency = 1,
		}, {
			stroke = e("UIStroke", {
				Color = COLOR.ink,
				Thickness = 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			mark = if member.box == "x"
				then e(PaperLabel, {
					text = "X",
					role = "marker",
					size = TEXT.body,
					color = COLOR.inkRed,
					anchor = Vector2.new(0.5, 0.5),
					position = UDim2.fromScale(0.5, 0.5),
					fit = true,
				})
				elseif member.box == "tick" then tick()
				else nil,
		}),
		-- Long display names and statuses are clipped to their columns (Figma's columns are fixed).
		name = e("Frame", {
			Position = UDim2.fromOffset(NAME_LEFT, 0),
			Size = UDim2.new(0, NAME_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
		}, {
			label = e(PaperLabel, {
				text = member.name,
				role = "heading",
				size = TEXT.body,
				strike = member.struck,
				frame = UDim2.fromScale(1, 1),
				autoSize = false,
				wrapped = false,
			}),
		}),
		status = e("Frame", {
			Position = UDim2.fromOffset(STATUS_LEFT, 0),
			Size = UDim2.new(1, -STATUS_LEFT - 16, 1, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
		}, {
			label = e(PaperLabel, {
				text = member.status,
				role = "body",
				size = TEXT.label,
				color = UIPaperConstants.inkColor(member.tone),
				frame = UDim2.fromScale(1, 1),
				autoSize = false,
				wrapped = false,
			}),
		}),
	})
end

-- Figma 1d "Crew strip": (50, 174) 232x56, tilted -1°, two 22 px lines 24 px apart under a binder clip.
local PHONE_LEFT = 50
local PHONE_TOP = 174
local PHONE_WIDTH = 232
local PHONE_TILT = -1
local PHONE_LINE = 24
local PHONE_PAD = 8

local function phoneSlip(roster: ShiftCrewViewModel.RosterView): React.ReactNode
	local children: { [string]: React.ReactNode } = {}
	for index, text in roster.compact do
		local top = PHONE_PAD - 2 + (index - 1) * PHONE_LINE
		children[`line{index}`] = e(PaperLabel, {
			text = text,
			role = "medium",
			size = PHONE_TEXT.body,
			color = if roster.compactDanger[index] then COLOR.inkRed else COLOR.ink,
			position = UDim2.fromOffset(10, top),
			frame = UDim2.new(1, -20, 0, 22),
			autoSize = false,
			wrapped = false,
		})
		if index > 1 then
			children[`rule{index}`] = e("Frame", {
				Position = UDim2.fromOffset(9, top - 1),
				Size = UDim2.new(1, -20, 0, 1),
				BackgroundColor3 = COLOR.manilaDeep,
				BorderSizePixel = 0,
			})
		end
	end
	local content: { [string]: React.ReactNode } = {
		-- Long lines are clipped to the slip, not shrunk below 15 px.
		clip = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
		}, children),
	}
	return e(PaperSheet, {
		position = UDim2.fromOffset(PHONE_LEFT, PHONE_TOP),
		size = UDim2.fromOffset(PHONE_WIDTH, PHONE_PAD + PHONE_LINE * math.max(#roster.compact, 1)),
		paper = COLOR.cream,
		tilt = PHONE_TILT,
		fastener = "clip",
		padding = 0,
		children = content,
	})
end

local function ShiftCrewRoster(props: ShiftCrewRosterProps): React.ReactNode
	local roster = props.roster
	if props.layout == "phone" then
		return phoneSlip(roster)
	end
	local children: { [string]: React.ReactNode } = {
		title = e(PaperLabel, {
			text = roster.title,
			role = "heading",
			size = TEXT.label,
			position = UDim2.fromOffset(16, 8),
			frame = UDim2.new(1, -32, 0, 30),
			autoSize = false,
			wrapped = false,
		}),
		titleRule = e("Frame", {
			Position = UDim2.fromOffset(16, 40),
			Size = UDim2.new(1, -32, 0, 2),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
		}),
	}
	for index, member in roster.members do
		children[`member{member.userId}`] = row(index, member)
	end
	return e(PaperSheet, {
		position = UDim2.fromOffset(LEFT, TOP),
		size = UDim2.fromOffset(WIDTH, HEADER + ROW * #roster.members),
		paper = COLOR.cream,
		fastener = "clip",
		padding = 0,
		children = children,
	})
end

return ShiftCrewRoster
