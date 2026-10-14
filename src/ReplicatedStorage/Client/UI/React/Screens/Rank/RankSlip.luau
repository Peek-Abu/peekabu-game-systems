--!strict
--[=[
	RankSlip: the company rank on the performance review (Cleanup Crew "Clearance Level"), typed onto the folder's
	paper like the rest of the review: "CLEARANCE LEVEL n · RANK" in heading ink, a ruled XP bar filled in the level's
	lanyard colour, the XP and "Next: ..." in typewriter body, this shift's XP in marker ink with its breakdown, a
	PROMOTED stamp (top right) once a level-up has landed, and "Incident Report filed" in stamp red for a caught player. Desktop
	draws it at 700x136 design px; the phone draws one 344x26 line and a thin bar. Presentational: the words are
	RankViewModel.slip.

	@class RankSlip
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local RankViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Rank.RankViewModel)

local e = React.createElement

export type RankSlipProps = {
	view: RankViewModel.SlipView,
	layout: UIPaperConstants.Layout,
	position: UDim2,
}

type Nodes = { [string]: React.ReactNode }

local COLOR = UIPaperConstants.COLOR
local DESKTOP = Vector2.new(700, 136)
local PHONE = Vector2.new(344, 26)

local function text(
	value: string,
	role: PaperLabel.Role,
	size: number,
	x: number,
	y: number,
	width: number,
	color: Color3?,
	align: ("left" | "center" | "right")?
): React.ReactNode
	return e(PaperLabel, {
		text = value,
		role = role,
		size = size,
		color = color,
		align = align,
		position = UDim2.fromOffset(x, y),
		frame = UDim2.fromOffset(width, math.ceil(size * 1.3)),
		autoSize = false,
		wrapped = false,
		scaled = true,
	})
end

-- The XP bar: an ink-ruled track on the paper, filled in the lanyard colour.
local function bar(fill: number, color: Color3, y: number, width: number, height: number): React.ReactNode
	return e("Frame", {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		track = e("UIStroke", { Color = COLOR.ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		fill = e("Frame", {
			Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}),
	})
end

local function desktopOf(view: RankViewModel.SlipView): Nodes
	local width = DESKTOP.X
	local nodes: Nodes = {
		rule = e("Frame", {
			Size = UDim2.fromOffset(width, 2),
			BackgroundColor3 = COLOR.companyTeal,
			BorderSizePixel = 0,
		}),
		heading = text(`{view.heading}  ·  {view.rank}`, "heading", 22, 0, 10, 520),
		bar = bar(view.fill, view.lanyard, 42, width, 14),
		xp = text(view.xpText, "body", 20, 0, 62, 220),
		next = text(view.next, "body", 18, 0, 90, width),
	}
	local gain = view.gain
	if gain ~= nil then
		nodes.gain = text(gain, "marker", 22, 300, 60, width - 300, COLOR.inkGreen, "right")
	end
	local breakdown = view.breakdown
	local incident = view.incident
	if breakdown ~= nil then
		nodes.breakdown = text(breakdown, "body", 15, 0, 114, if incident ~= nil then 500 else width)
	end
	if incident ~= nil then
		nodes.incident = text(incident, "heading", 18, 510, 112, width - 510, COLOR.stamp, "right")
	end
	if view.promoted then
		nodes.promoted = e(PaperStamp, {
			text = "PROMOTED",
			size = 28,
			tilt = -4,
			pop = true,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.fromOffset(width, 20),
		})
	end
	return nodes
end

local function phoneOf(view: RankViewModel.SlipView): Nodes
	local width = PHONE.X
	local nodes: Nodes = {
		heading = text(view.rank, "heading", 14, 0, 0, 230),
		bar = bar(view.fill, view.lanyard, 20, width, 6),
	}
	local gain = view.gain
	if gain ~= nil then
		nodes.gain = text(
			if view.promoted then `PROMOTED {gain}` else gain,
			"heading",
			14,
			230,
			0,
			width - 230,
			COLOR.inkGreen,
			"right"
		)
	end
	return nodes
end

local function RankSlip(props: RankSlipProps): React.ReactNode
	local phone = props.layout == "phone"
	local size = if phone then PHONE else DESKTOP
	return e("Frame", {
		Position = props.position,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, if phone then phoneOf(props.view) else desktopOf(props.view))
end

return RankSlip
