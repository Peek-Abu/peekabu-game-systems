--!strict
--[=[
	CompanyWorkOrderTracker: the Today tracker card (lines from CompanyTrackerViewModel). The Timecard line on top (gold
	while today's punch is still free), the Daily Work Order with its meter, and the reward or the time to tomorrow's
	order under it. In the hub it sits under the COMPANY CLIPBOARD button and a tap opens the clipboard; in a shift it
	keeps the old spots (right side on desktop, above the thumbstick on phone, where it drops the footer). × unpins it.

	@class CompanyWorkOrderTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local CompanyTrackerViewModel = require(script.Parent.CompanyTrackerViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local Surface = require(Toon.ToonSurface)
local Text = require(Toon.ToonText)
local Bar = require(Toon.ToonBar)
local Button = require(Toon.ToonButton)
local Icon = require(Toon.ToonIcon)
local Style = require(Toon.UIToonConstants)
local e = React.createElement
export type Props = {
	phone: boolean,
	where: CompanyTrackerViewModel.Where,
	lines: CompanyTrackerViewModel.Lines,
	onUnpin: () -> (),
	-- The hub's tap on the card: opens the clipboard.
	onOpen: (() -> ())?,
}

local function frame(props: Props): (UDim2, UDim2, Vector2)
	if props.where == "hub" then
		-- Under the hub's COMPANY CLIPBOARD button (DepotTimecardPanel: 300x48 at 840,78; phone 220x48 at 410,8).
		return if props.phone then UDim2.fromOffset(410, 62) else UDim2.fromOffset(840, 134),
			if props.phone then UDim2.fromOffset(220, 84) else UDim2.fromOffset(300, 132),
			Vector2.zero
	end
	return if props.phone then UDim2.fromOffset(14, 120) else UDim2.new(1, -24, 0, 180),
		if props.phone then UDim2.fromOffset(240, 78) else UDim2.fromOffset(370, 132),
		if props.phone then Vector2.zero else Vector2.new(1, 0)
end

local function Panel(props: Props): React.ReactNode
	local lines = props.lines
	local phone = props.phone
	local compact = phone and props.where == "shift"
	local content: { [string]: React.ReactNode } = {
		icon = e(Icon, {
			icon = if lines.timecardDue then "clock" else "jobs",
			position = UDim2.fromOffset(-8, -10),
			size = UDim2.fromOffset(if phone then 38 else 48, if phone then 38 else 48),
			rotation = -12,
			zIndex = 3,
		}),
		timecard = e(Text, {
			text = lines.timecard,
			font = "body",
			color = Style.COLOR.white,
			textSize = if phone then 14 else 18,
			position = UDim2.fromOffset(if phone then 34 else 42, 5),
			size = UDim2.new(1, if phone then -76 else -86, 0, if phone then 16 else 22),
			fit = true,
		}),
		title = e(Text, {
			text = lines.order,
			font = "body",
			color = Style.COLOR.white,
			textSize = if phone then 16 else 22,
			position = UDim2.fromOffset(12, if phone then 22 else 30),
			size = UDim2.new(1, -24, 0, if phone then 20 else 28),
			fit = true,
		}),
		meter = e(Bar, {
			kind = "xp",
			fill = math.clamp(lines.progress / math.max(1, lines.target), 0, 1),
			label = `{lines.progress} / {lines.target}`,
			labelSize = if phone then 14 else 20,
			position = UDim2.fromOffset(12, if phone then 44 else 62),
			size = UDim2.new(1, -24, 0, if phone then 18 else 30),
		}),
		footer = if compact
			then nil
			else e(Text, {
				text = lines.footer,
				font = "body",
				color = Style.COLOR.white,
				textSize = if phone then 13 else 17,
				align = "right",
				position = UDim2.new(0, 12, 1, if phone then -20 else -30),
				size = UDim2.new(1, -24, 0, if phone then 16 else 22),
				fit = true,
			}),
		hide = e(Button, {
			variant = "danger",
			text = "X",
			textSize = if phone then 13 else 16,
			layout = "inline",
			small = true,
			sound = "back",
			position = UDim2.new(1, if phone then -30 else -38, 0, 4),
			size = UDim2.fromOffset(if phone then 24 else 30, if phone then 22 else 26),
			zIndex = 5,
			onActivated = props.onUnpin,
		}),
	}
	local position, size, anchor = frame(props)
	local onOpen = props.onOpen
	return e("Frame", {
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
	}, {
		card = e(Surface, {
			hue = if lines.timecardDue and props.where == "hub" then "gold" else "grape",
			pattern = "bubbles",
			radius = 16,
			size = UDim2.fromScale(1, 1),
			children = content,
		}),
		open = if onOpen ~= nil
			then e("TextButton", {
				Text = "",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -44, 1, 0),
				ZIndex = 4,
				[React.Event.Activated] = function()
					onOpen()
				end,
			})
			else nil,
	})
end
return Panel
