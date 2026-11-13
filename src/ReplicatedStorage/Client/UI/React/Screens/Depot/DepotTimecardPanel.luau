--!strict
--[=[
	DepotTimecardPanel: the Company Clipboard (owner pick 2026-11-13, layout A, fewer words). A coral clipboard with a
	steel clip holds two tabs and one sheet:
	- TIMECARD (sky): a track of punch slots (done in gold with a tick, today's in mint with a ring, the rest empty),
	  the Gloom Key hung under the key punch and the Gleam under the last, a big PUNCH IN! and the paycheck as a row
	  of dots (one per full week);
	- TODAY'S JOB (mint): the order in big words with its render, a progress bar, the reward chip and the time to the
	  next job, and the button that shows it during shifts.
	The X closes it. Layout and words come from the specced DepotClipboardViewModel.

	@class DepotTimecardPanel
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Rules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local Constants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)
local Registry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonSurface = require(Toon.ToonSurface)
local ToonButton = require(Toon.ToonButton)
local ToonText = require(Toon.ToonText)
local ToonBar = require(Toon.ToonBar)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local UIToonConstants = require(Toon.UIToonConstants)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local TimecardMomentUtils = require(ReplicatedStorage.Client.Features.Timecard.Utils.TimecardMomentUtils)
local DepotTimecardStamp = require(script.Parent.DepotTimecardStamp)
local VM = require(script.Parent.DepotClipboardViewModel)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local e = React.createElement
local COLOR = UIToonConstants.COLOR
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

-- A circle Frame on the ink outline (the kit's stack, drawn small): a slot or a paycheck dot.
local function disc(props: {
	center: Vector2,
	size: number,
	color: Color3,
	stroke: number,
	ring: boolean?,
	zIndex: number?,
	children: { [string]: React.ReactNode }?,
}): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		outline = e("UIStroke", { Color = COLOR.ink, Thickness = props.stroke }),
	}
	local extra = props.children
	if extra ~= nil then
		for key, node in extra do
			children[key] = node
		end
	end
	local frame = e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(props.center.X, props.center.Y),
		Size = UDim2.fromOffset(props.size, props.size),
		BackgroundColor3 = props.color,
		BorderSizePixel = 0,
		ZIndex = props.zIndex or 3,
	}, children)
	if props.ring ~= true then
		return frame
	end
	-- Today's slot: a white ring and a second ink ring around it, so the next punch is the first thing you see.
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(props.center.X, props.center.Y),
		Size = UDim2.fromOffset(props.size + 20, props.size + 20),
		BackgroundColor3 = COLOR.white,
		BorderSizePixel = 0,
		ZIndex = (props.zIndex or 3) - 1,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		outline = e("UIStroke", { Color = COLOR.ink, Thickness = props.stroke }),
		inner = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(props.size, props.size),
			BackgroundColor3 = props.color,
			BorderSizePixel = 0,
			ZIndex = props.zIndex or 3,
		}, children),
	})
end

-- A tick drawn from two white bars on ink (no glyph): the short leg and the long one.
local function tick(size: number): { [string]: React.ReactNode }
	local function bar(length: number, rotation: number, offset: Vector2): React.ReactNode
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
			Size = UDim2.fromOffset(length, math.floor(size * 0.15)),
			Rotation = rotation,
			BackgroundColor3 = COLOR.white,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			outline = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }),
		})
	end
	return {
		short = bar(math.floor(size * 0.3), 45, Vector2.new(-size * 0.13, size * 0.06)),
		long = bar(math.floor(size * 0.55), -50, Vector2.new(size * 0.08, -size * 0.02)),
	}
end

local function timecardFace(props: Props): { [string]: React.ReactNode }
	local status = props.status
	local slots = VM.slots(status)
	local first = VM.slotCenter(1)
	local last = VM.slotCenter(#slots)
	local face: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = `PUNCH IN {Constants.PUNCHES_TO_FILL} DAYS`,
			textSize = 34,
			position = UDim2.fromOffset(22, 14),
			size = UDim2.fromOffset(380, 42),
			fit = true,
			zIndex = 3,
		}),
		done = e(ToonText, {
			text = if props.feedback ~= "" then props.feedback else VM.done(status),
			font = "body",
			textSize = 22,
			align = "right",
			position = UDim2.fromOffset(400, 20),
			size = UDim2.fromOffset(218, 30),
			fit = true,
			zIndex = 3,
		}),
		track = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(first.X, first.Y),
			Size = UDim2.fromOffset(last.X - first.X, 16),
			BackgroundColor3 = COLOR.ink,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		punch = e(ToonButton, {
			text = if status.canPunch then "PUNCH IN!" else "PUNCHED TODAY",
			textSize = 30,
			variant = "primary",
			position = UDim2.fromOffset(20, 262),
			size = UDim2.fromOffset(290, 56),
			disabled = not status.canPunch or props.pending == true,
			onActivated = props.onPunch,
			zIndex = 3,
		}),
	}
	for _, slot in slots do
		local center = VM.slotCenter(slot.number)
		local color = if slot.state == "done"
			then UIToonConstants.shade("gold").base
			elseif slot.state == "today" then UIToonConstants.shade("mint").base
			else UIToonConstants.shade("sky").hi
		local inside: { [string]: React.ReactNode } = if slot.state == "done"
			then tick(VM.SLOT)
			else {
				number = e(ToonText, {
					text = tostring(slot.number),
					textSize = 40,
					align = "center",
					alignY = "center",
					size = UDim2.fromScale(1, 1),
					transparency = if slot.state == "empty" then 0.45 else 0,
					zIndex = 5,
				}),
			}
		face[`slot{slot.number}`] = disc({
			center = center,
			size = VM.SLOT,
			color = color,
			stroke = 5,
			ring = slot.state == "today",
			zIndex = 4,
			children = inside,
		})
		local prize = slot.prize
		if prize ~= nil then
			face[`prize{slot.number}`] = e(ToonIcon, {
				icon = if prize == "key" then "key" else "gleam",
				anchor = Vector2.new(0.5, 0),
				position = UDim2.fromOffset(center.X, center.Y + VM.SLOT / 2 + 8),
				size = UDim2.fromOffset(60, 56),
				drop = 3,
				zIndex = 3,
			})
			face[`prizeText{slot.number}`] = e(ToonText, {
				text = if prize == "key"
					then `{Constants.KEY_REWARD} GLOOM KEY`
					else `{Constants.STAR_REWARD} {string.upper(Constants.STAR_LABEL)}`,
				textSize = 20,
				align = "center",
				anchor = Vector2.new(0.5, 0),
				position = UDim2.fromOffset(center.X, center.Y + VM.SLOT / 2 + 64),
				size = UDim2.fromOffset(140, 24),
				fit = true,
				zIndex = 3,
			})
		end
	end
	-- The paycheck: a dot per full week, then what it pays.
	local paycheck = VM.paycheck(status)
	local chip: { [string]: React.ReactNode } = {
		pay = e(ToonText, {
			text = `= {paycheck.credits}`,
			textSize = 24,
			meaning = "gold",
			position = UDim2.fromOffset(20 + paycheck.total * 34 + 6, 8),
			size = UDim2.fromOffset(84, 30),
			fit = true,
			zIndex = 4,
		}),
		coin = e(ToonIcon, {
			icon = "credits",
			position = UDim2.fromOffset(20 + paycheck.total * 34 + 90, -6),
			size = UDim2.fromOffset(58, 54),
			drop = 3,
			zIndex = 4,
		}),
	}
	for dot = 1, paycheck.total do
		chip[`week{dot}`] = disc({
			center = Vector2.new(20 + (dot - 1) * 34 + 13, 23),
			size = 24,
			color = if dot <= paycheck.filled then UIToonConstants.shade("gold").base else COLOR.white,
			stroke = 3,
			zIndex = 4,
		})
	end
	face.paycheck = e(ToonSurface, {
		hue = "night",
		small = true,
		radius = 23,
		position = UDim2.fromOffset(330, 266),
		size = UDim2.fromOffset(290, 48),
		children = chip,
	})
	local stamp = props.stamp
	if stamp ~= nil then
		face.stamp = e(DepotTimecardStamp, { moment = stamp, banner = TimecardMomentUtils.banner(stamp) })
	end
	return face
end

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
			position = UDim2.fromOffset(340, 202),
			size = UDim2.fromOffset(280, 44),
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
					size = UDim2.fromOffset(216, 30),
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
			position = UDim2.fromOffset(238, 204),
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
					Size = UDim2.fromOffset(500, 56),
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
						textSize = 26,
						variant = "sky",
						selected = not job,
						receded = job,
						size = UDim2.fromOffset(230, 56),
						layoutOrder = 1,
						onActivated = props.onTimecard or props.onToggle,
					}),
					daily = e(ToonButton, {
						text = "TODAY'S JOB",
						icon = "jobs",
						textSize = 26,
						variant = "primary",
						selected = job,
						receded = not job,
						size = UDim2.fromOffset(250, 56),
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
