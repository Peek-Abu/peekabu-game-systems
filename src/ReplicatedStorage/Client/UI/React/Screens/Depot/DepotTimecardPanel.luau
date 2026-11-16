--!strict
--[=[
	DepotTimecardPanel: the Company Clipboard (owner pick 2026-11-13, layout A, fewer words). A coral clipboard with a
	steel clip holds two tabs and one sheet:
	- TIMECARD (sky): a track of punch slots (done in gold with a tick, today's in mint with a ring, the rest empty),
	  the Gloom Key hung under the key punch and the Gleam under the last, a big PUNCH IN! and the paycheck as a row
	  of dots (one per full week);
	- TODAY'S JOB (mint): the order in big words with its render, a progress bar, the reward chip and the time to the
	  next job, and the button that shows it during shifts.
	The X closes it. Layout and words come from the specced DepotClipboardViewModel. The TIMECARD sheet is drawn by
	DepotTimecardFace, split out of this file.

	@class DepotTimecardPanel
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Rules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local Registry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonSurface = require(Toon.ToonSurface)
local ToonButton = require(Toon.ToonButton)
local ToonText = require(Toon.ToonText)
local ToonBar = require(Toon.ToonBar)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local TimecardMomentUtils = require(ReplicatedStorage.Client.Features.Timecard.Utils.TimecardMomentUtils)
local timecardFace = require(script.Parent.DepotTimecardFace)
local VM = require(script.Parent.DepotClipboardViewModel)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local e = React.createElement
local function nodes(value: { [string]: React.ReactNode }): { [string]: React.ReactNode }
	return value
end
export type Props = {
	phone: boolean,
	view: ("timecard" | "workOrder")?,
	now: number?,
	kind: Registry.Kind?,
	onWorkOrder: (() -> ())?,
	onTimecard: (() -> ())?,
	onPin: (() -> ())?,
	-- Draw the mid-top COMPANY CLIPBOARD button (default true).
	button: boolean?,
	pinned: boolean?,
	onClose: (() -> ())?,
	open: boolean,
	status: Rules.Status,
	progress: number,
	target: number,
	order: string,
	claimed: boolean,
	feedback: string,
	pending: boolean?,
	onToggle: () -> (),
	onPunch: () -> (),
	-- Today's punch landing (TimecardMomentStore.stamp): drawn over the Timecard face while it shows.
	stamp: TimecardMomentUtils.Moment?,
}
-- Inherit the shared HUD scale; a phone draws the clipboard a little smaller so it fits under the top bar.
local function CardScale(props: { factor: number, content: { [string]: React.ReactNode } }): React.ReactNode
	local outer = React.useContext(PaperScaleContext.Context)
	local deps: { unknown } = { outer, props.factor }
	local combined = React.useMemo(function()
		return outer:map(function(value: number): number
			return value * props.factor
		end)
	end, deps)
	local inside: { [string]: React.ReactNode } = { scale = e("UIScale", { Scale = props.factor }) }
	for key, node in props.content do
		inside[key] = node
	end
	return e(PaperScaleContext.Context.Provider, { value = combined }, {
		frame = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(VM.BOARD.X, VM.BOARD.Y),
			BackgroundTransparency = 1,
		}, inside),
	})
end

local ART: { [Registry.Kind]: UIAssets.ToonIcon } = {
	cargo = "truck",
	piles = "vacuum",
	salvage = "gleam",
	shifts = "jobs",
}
local INSTRUCTIONS: { [Registry.Kind]: string } = {
	piles = "Vacuum piles in any shift.",
	cargo = "Load cargo into the truck.",
	salvage = "Bank salvage in overtime.",
	shifts = "Finish shifts with your crew.",
}

local function workOrderFace(props: Props): { [string]: React.ReactNode }
	local kind: Registry.Kind = if props.kind ~= nil then props.kind else "shifts"
	local face: { [string]: React.ReactNode } = {
		objectiveArt = e(ToonIcon, {
			icon = ART[kind],
			position = UDim2.fromOffset(12, 6),
			size = UDim2.fromOffset(116, 108),
			rotation = -8,
			zIndex = 3,
		}),
		objective = e(ToonText, {
			text = string.upper(props.order),
			textSize = 40,
			position = UDim2.fromOffset(138, 22),
			size = UDim2.fromOffset(484, 50),
			fit = true,
			zIndex = 3,
		}),
		instructions = e(ToonText, {
			text = INSTRUCTIONS[kind],
			font = "body",
			textSize = 22,
			position = UDim2.fromOffset(140, 74),
			size = UDim2.fromOffset(480, 30),
			fit = true,
			zIndex = 3,
		}),
		meter = e(ToonBar, {
			kind = "xp",
			fill = math.clamp(props.progress / math.max(1, props.target), 0, 1),
			label = `{props.progress} / {props.target}`,
			labelSize = 28,
			position = UDim2.fromOffset(20, 128),
			size = UDim2.fromOffset(600, 44),
		}),
		rewardPlate = e(ToonSurface, {
			hue = "gold",
			small = true,
			radius = 28,
			position = UDim2.fromOffset(20, 196),
			size = UDim2.fromOffset(210, 56),
			children = nodes({
				icon = e(ToonIcon, {
					icon = "credits",
					position = UDim2.fromOffset(-10, -12),
					size = UDim2.fromOffset(78, 72),
					rotation = -12,
					drop = 3,
					zIndex = 4,
				}),
				reward = e(ToonText, {
					text = `+{Registry.REWARD_CREDITS}`,
					textSize = 36,
					meaning = "gold",
					position = UDim2.fromOffset(74, 6),
					size = UDim2.fromOffset(124, 40),
					fit = true,
					zIndex = 4,
				}),
			}),
		}),
		reset = e(ToonSurface, {
			hue = "night",
			small = true,
			radius = 22,
			position = UDim2.fromOffset(280, 202),
			size = UDim2.fromOffset(340, 44),
			children = nodes({
				clock = e(ToonIcon, {
					icon = "clock",
					position = UDim2.fromOffset(-8, -8),
					size = UDim2.fromOffset(54, 54),
					drop = 3,
					zIndex = 4,
				}),
				text = e(ToonText, {
					text = VM.newJob(props.now or 0),
					textSize = 22,
					position = UDim2.fromOffset(52, 7),
					size = UDim2.fromOffset(276, 30),
					fit = true,
					zIndex = 4,
				}),
			}),
		}),
		pin = e(ToonButton, {
			text = if props.pinned then "SHOWING IN SHIFTS" else "SHOW IN SHIFTS",
			textSize = 24,
			variant = "sky",
			position = UDim2.fromOffset(20, 268),
			size = UDim2.fromOffset(330, 50),
			disabled = props.onPin == nil,
			onActivated = props.onPin or function() end,
			zIndex = 3,
		}),
	}
	if props.claimed then
		face.paid = e(ToonFlag, {
			text = "PAID",
			hue = "mint",
			textSize = 26,
			-- Stamped over the full bar's end.
			position = UDim2.fromOffset(516, 130),
			size = UDim2.fromOffset(96, 40),
		})
	end
	return face
end

-- The steel clip on the board's top edge, with the board's name on it.
local function clip(): React.ReactNode
	return e(ToonSurface, {
		hue = "steel",
		small = true,
		radius = 16,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0),
		size = UDim2.fromOffset(220, 44),
		children = nodes({
			title = e(ToonText, {
				text = "CLIPBOARD",
				textSize = 22,
				align = "center",
				alignY = "center",
				size = UDim2.fromScale(1, 1),
				zIndex = 4,
			}),
		}),
	})
end

local function Panel(props: Props): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		-- The mid-top COMPANY CLIPBOARD button (a minimized hub layout opens the card from its own button instead).
		toggle = if props.button == false
			then nil
			else e(ToonButton, {
				text = "COMPANY CLIPBOARD",
				textSize = 22,
				variant = "secondary",
				size = UDim2.fromOffset(if props.phone then 220 else 300, 48),
				position = UDim2.fromOffset(if props.phone then 410 else 840, if props.phone then 8 else 78),
				onActivated = props.onToggle,
			}),
	}
	if props.open then
		local job = props.view == "workOrder"
		children.card = e(CardScale, {
			factor = if props.phone then 0.78 else 1,
			content = {
				board = e(ToonSurface, {
					hue = "coral",
					pattern = "bubbles",
					radius = 30,
					size = UDim2.fromScale(1, 1),
				}),
				clip = clip(),
				close = e(ToonButton, {
					variant = "danger",
					text = "X",
					textSize = 30,
					anchor = Vector2.new(1, 0),
					position = UDim2.new(1, -14, 0, 18),
					size = UDim2.fromOffset(60, 54),
					sound = "back",
					onActivated = props.onClose or props.onToggle,
					zIndex = 6,
				}),
				tabs = e("Frame", {
					Size = UDim2.fromOffset(560, 56),
					Position = UDim2.fromOffset(22, 26),
					BackgroundTransparency = 1,
					ZIndex = 5,
				}, {
					list = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 16),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					timecard = e(ToonButton, {
						text = "TIMECARD",
						icon = "clock",
						textSize = 24,
						variant = "sky",
						selected = not job,
						receded = job,
						size = UDim2.fromOffset(240, 56),
						layoutOrder = 1,
						onActivated = props.onTimecard or props.onToggle,
					}),
					daily = e(ToonButton, {
						text = "TODAY'S JOB",
						icon = "jobs",
						textSize = 24,
						variant = "primary",
						selected = job,
						receded = not job,
						size = UDim2.fromOffset(290, 56),
						layoutOrder = 2,
						onActivated = props.onWorkOrder or props.onToggle,
					}),
				}),
				card = e(ToonSurface, {
					hue = if job then "mint" else "sky",
					radius = 24,
					position = UDim2.fromOffset(VM.SHEET_AT.X, VM.SHEET_AT.Y),
					size = UDim2.fromOffset(VM.SHEET.X, VM.SHEET.Y),
					children = if job then workOrderFace(props) else timecardFace(props),
				}),
			},
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
		-- While the card is open the training spotlight waits (Pippa never sits on it).
		[React.Tag] = if props.open then TrainingConstants.SPOTLIGHT_TAGS.popup else nil,
	}, children)
end
return Panel
