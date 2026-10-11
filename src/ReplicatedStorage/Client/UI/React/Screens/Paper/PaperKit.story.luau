--!strict
--[=[
	PaperKit.story: every piece of Cleanup Crew's paper UI kit on the dark office, in Studio's edit mode (UI Labs),
	for the side-by-side check against Figma Style 4:2 and Components 5:2. `Pop` remounts the stamps so they drop in
	again; `Tilt` turns the manila sheet and the sticky notes.

	@class PaperKit.story
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local KeyChip = require(ReplicatedStorage.Client.UI.React.Screens.Paper.KeyChip)
local PaperButton = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperButton)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local PaperStamp = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperStamp)
local StickyNote = require(ReplicatedStorage.Client.UI.React.Screens.Paper.StickyNote)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

local COLOR = UIPaperConstants.COLOR
local TEXT = UIPaperConstants.TEXT.desktop

local function noop() end

local function row(order: number, height: number, children: { [string]: React.ReactNode }): React.ReactNode
	local content: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 40),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for key, node in children do
		content[key] = node
	end
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
	}, content)
end

local function stack(order: number, children: { [string]: React.ReactNode }): React.ReactNode
	local content: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 24),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for key, node in children do
		content[key] = node
	end
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, content)
end

-- One label per type role, on cream paper.
local function roleSheet(order: number): React.ReactNode
	return e(PaperSheet, {
		size = UDim2.fromOffset(420, 330),
		paper = COLOR.cream,
		fastener = "staple",
		layoutOrder = order,
	}, {
		layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		body = e(PaperLabel, { text = "body: Clear 350 of trash.", role = "body", size = TEXT.body, layoutOrder = 1 }),
		heading = e(PaperLabel, { text = "HEADING: QUOTA MET", role = "heading", size = TEXT.value, layoutOrder = 2 }),
		medium = e(PaperLabel, { text = "Medium: Pressure", role = "medium", size = TEXT.label, layoutOrder = 3 }),
		number = e(PaperLabel, { text = "350 / 350", role = "number", size = TEXT.value, layoutOrder = 4 }),
		timer = e(PaperLabel, { text = "4:12", role = "timer", size = TEXT.big, layoutOrder = 5 }),
		marker = e(PaperLabel, {
			text = "your vote",
			role = "marker",
			size = TEXT.sticky,
			color = UIPaperConstants.inkColor("busy"),
			layoutOrder = 6,
		}),
		struck = e(PaperLabel, {
			text = "Finch & <Co>",
			role = "body",
			size = TEXT.body,
			strike = true,
			color = UIPaperConstants.inkColor("muted"),
			layoutOrder = 7,
		}),
	})
end

return UILabs.CreateReactStory({
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		Pop = false,
		Tilt = 2,
	},
}, function(props)
	local pop: boolean = props.controls.Pop
	local tilt: number = props.controls.Tilt
	-- A new key remounts the stamps and the wide note, so turning Pop on plays their motion again.
	local stampKey = if pop then "popped" else "still"

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.office,
		BorderSizePixel = 0,
	}, {
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 40),
			PaddingTop = UDim.new(0, 60),
		}),
		layout = e("UIListLayout", { Padding = UDim.new(0, 40), SortOrder = Enum.SortOrder.LayoutOrder }),
		sheets = row(1, 240, {
			manila = e(PaperSheet, {
				size = UDim2.fromOffset(340, 200),
				tab = "CLEARANCE CONTRACT",
				fastener = "clip",
				tilt = tilt,
				layoutOrder = 1,
			}, {
				layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
				title = e(
					PaperLabel,
					{ text = "Harlow & Finch Ltd.", role = "heading", size = TEXT.value, layoutOrder = 1 }
				),
				body = e(PaperLabel, {
					text = "Clear the office before the sale.",
					role = "body",
					size = TEXT.body,
					layoutOrder = 2,
				}),
			}),
			cream = e(PaperSheet, {
				size = UDim2.fromOffset(340, 200),
				paper = COLOR.cream,
				band = "HARLOW & FINCH — TIME CARD",
				fastener = "pin",
				torn = true,
				layoutOrder = 2,
			}, {
				shift = e(PaperLabel, { text = "SHIFT", role = "body", size = TEXT.label }),
				timer = e(PaperLabel, {
					text = "4:12",
					role = "timer",
					size = TEXT.timer,
					position = UDim2.fromOffset(0, 28),
				}),
			}),
			stamps = stack(3, {
				[`big{stampKey}`] = e(
					PaperStamp,
					{ text = "QUOTA MET", size = TEXT.stamp, pop = pop, layoutOrder = 1 }
				),
				[`small{stampKey}`] = e(PaperStamp, { text = "QUOTA MET", size = 40, pop = pop, layoutOrder = 2 }),
			}),
		}),
		notes = row(2, 200, {
			[`wide{stampKey}`] = e(StickyNote, {
				text = "You hear Harlow pacing faster…",
				width = 340,
				size = TEXT.sticky,
				tilt = tilt,
				slide = pop,
				layoutOrder = 1,
			}),
			narrow = e(StickyNote, {
				text = "You hear Harlow pacing faster…",
				width = 250,
				size = UIPaperConstants.TEXT.phone.sticky,
				tilt = -tilt,
				layoutOrder = 2,
			}),
			e = e(KeyChip, { label = "E", size = TEXT.hint, layoutOrder = 3 }),
			lmb = e(KeyChip, { label = "LMB", size = TEXT.hint, layoutOrder = 4 }),
			left = e(KeyChip, { label = "←", size = TEXT.hint, layoutOrder = 5 }),
		}),
		buttons = row(3, 72, {
			primary = e(PaperButton, {
				text = "LABEL",
				variant = "primary",
				onActivated = noop,
				size = UDim2.fromOffset(160, 72),
				textSize = TEXT.label,
				layoutOrder = 1,
			}),
			secondary = e(PaperButton, {
				text = "LABEL",
				variant = "secondary",
				onActivated = noop,
				size = UDim2.fromOffset(160, 72),
				textSize = TEXT.label,
				layoutOrder = 2,
			}),
			danger = e(PaperButton, {
				text = "LABEL",
				variant = "danger",
				onActivated = noop,
				size = UDim2.fromOffset(160, 72),
				textSize = TEXT.label,
				layoutOrder = 3,
			}),
			go = e(PaperButton, {
				text = "LABEL",
				variant = "go",
				onActivated = noop,
				size = UDim2.fromOffset(160, 72),
				textSize = TEXT.label,
				layoutOrder = 4,
			}),
			disabled = e(PaperButton, {
				text = "LABEL",
				variant = "primary",
				disabled = true,
				onActivated = noop,
				size = UDim2.fromOffset(160, 72),
				textSize = TEXT.label,
				layoutOrder = 5,
			}),
		}),
		paper = row(4, 330, {
			onPaper = e(PaperSheet, {
				size = UDim2.fromOffset(420, 150),
				paper = COLOR.cream,
				fastener = "tape",
				layoutOrder = 1,
			}, {
				vote = e(PaperButton, {
					text = "KEEP GOING",
					variant = "secondary",
					onPaper = true,
					mark = "your vote",
					onActivated = noop,
					size = UDim2.fromOffset(200, 72),
					textSize = TEXT.label,
					anchor = Vector2.new(0, 0.5),
					position = UDim2.fromScale(0, 0.5),
				}),
			}),
			roles = roleSheet(2),
		}),
	})
end)
