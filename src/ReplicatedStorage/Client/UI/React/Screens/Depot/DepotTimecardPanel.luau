--!strict
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
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
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
}
-- Inherit the shared HUD scale; reserve phone clearance for the header art and hard drop.
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
			Size = UDim2.fromOffset(620, 390),
			BackgroundTransparency = 1,
		}, inside),
	})
end
local DAYS = { "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN" }
local function label(text: string, y: number, height: number): React.ReactNode
	return e(ToonText, {
		text = text,
		font = "body",
		textSize = 18,
		position = UDim2.fromOffset(22, y),
		size = UDim2.new(1, -44, 0, height),
		fit = true,
	})
end
local INSTRUCTIONS: { [Registry.Kind]: string } = {
	piles = "Help clear piles during your shifts.",
	cargo = "Load cargo into the truck during shifts.",
	salvage = "Bank salvage found during overtime.",
	shifts = "Finish shifts with your crew.",
}
local function workOrderFace(props: Props): { [string]: React.ReactNode }
	local kind: Registry.Kind = if props.kind ~= nil then props.kind else "shifts"
	local remaining = math.ceil(86400 - ((props.now or 0) % 86400))
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor(remaining / 60) % 60
	local seconds = remaining % 60
	local reset = string.format("%02d:%02d:%02d", hours, minutes, seconds)
	return {
		title = label("TODAY’S ASSIGNMENT", 124, 24),
		objective = e(ToonText, {
			text = props.order,
			textSize = 30,
			meaning = "grape",
			position = UDim2.fromOffset(116, 150),
			size = UDim2.new(1, -144, 0, 42),
			fit = true,
		}),
		instructions = e(ToonText, {
			text = INSTRUCTIONS[kind],
			font = "body",
			textSize = 17,
			position = UDim2.fromOffset(116, 189),
			size = UDim2.fromOffset(470, 24),
			fit = true,
		}),
		objectiveArt = e(ToonIcon, {
			icon = if kind == "cargo"
				then "truck"
				elseif kind == "piles" then "vacuum"
				elseif kind == "salvage" then "gleam"
				else "jobs",
			position = UDim2.fromOffset(24, 148),
			size = UDim2.fromOffset(80, 72),
			rotation = -8,
			zIndex = 3,
		}),
		meter = e(ToonBar, {
			kind = "xp",
			fill = math.clamp(props.progress / math.max(1, props.target), 0, 1),
			label = `{props.progress} / {props.target}`,
			labelSize = 24,
			position = UDim2.fromOffset(24, 224),
			size = UDim2.new(1, -48, 0, 30),
		}),
		rewardPlate = e(ToonSurface, {
			hue = "gold",
			small = true,
			radius = 14,
			position = UDim2.fromOffset(24, 268),
			size = UDim2.fromOffset(264, 50),
			children = nodes({
				icon = e(ToonIcon, {
					icon = "credits",
					position = UDim2.fromOffset(0, -8),
					size = UDim2.fromOffset(64, 60),
					rotation = -12,
				}),
			}),
		}),
		reward = e(ToonText, {
			text = `REWARD: {Registry.REWARD_CREDITS} CREDITS`,
			textSize = 22,
			position = UDim2.fromOffset(86, 278),
			size = UDim2.fromOffset(194, 28),
			fit = true,
			zIndex = 3,
		}),
		state = e(ToonText, {
			text = if props.claimed then "COMPLETED • REWARD PAID" else "Paid automatically when complete",
			font = "body",
			textSize = 16,
			position = UDim2.fromOffset(310, 307),
			size = UDim2.fromOffset(286, 22),
			fit = true,
		}),
		reset = e(ToonText, {
			text = `NEW ORDER IN {reset} • UTC`,
			font = "body",
			textSize = 16,
			position = UDim2.fromOffset(310, 280),
			size = UDim2.fromOffset(286, 24),
			fit = true,
		}),
		stamp = if props.claimed
			then e(ToonFlag, {
				text = "PAID",
				hue = "mint",
				textSize = 24,
				position = UDim2.fromOffset(456, 120),
				size = UDim2.fromOffset(130, 36),
			})
			else nil,
		pin = e(ToonButton, {
			text = if props.pinned then "PINNED FOR SHIFTS" else "PIN FOR SHIFTS",
			textSize = 20,
			variant = "primary",
			position = UDim2.fromOffset(22, 340),
			size = UDim2.fromOffset(330, 34),
			disabled = props.onPin == nil,
			onActivated = props.onPin or function() end,
		}),
		close = e(ToonButton, {
			text = "CLOSE",
			variant = "secondary",
			position = UDim2.fromOffset(380, 340),
			size = UDim2.fromOffset(220, 34),
			onActivated = props.onClose or props.onToggle,
		}),
	}
end
local function Panel(props: Props): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		toggle = e(ToonButton, {
			text = "COMPANY CLIPBOARD",
			textSize = 22,
			variant = "secondary",
			size = UDim2.fromOffset(if props.phone then 220 else 300, 48),
			position = UDim2.fromOffset(if props.phone then 410 else 840, if props.phone then 8 else 78),
			onActivated = props.onToggle,
		}),
	}
	if props.open then
		local face: { [string]: React.ReactNode } = {
			title = label(`WEEK OF {props.status.weekKey} • {props.status.count}/5 DAYS`, 124, 24),
			rule = label(
				if props.feedback == "" then "Any 5 days • Missed days keep your punches • UTC" else props.feedback,
				148,
				24
			),
			rewards = e(ToonSurface, {
				hue = "lilac",
				small = true,
				radius = 14,
				position = UDim2.fromOffset(24, 246),
				size = UDim2.fromOffset(276, 52),
				children = nodes({
					icon = e(ToonIcon, {
						icon = "key",
						position = UDim2.fromOffset(2, -6),
						size = UDim2.fromOffset(66, 58),
						rotation = -12,
					}),
					title = e(ToonText, {
						text = `{Constants.KEY_REWARD} GLOOM KEY`,
						textSize = 22,
						position = UDim2.fromOffset(72, 2),
						size = UDim2.fromOffset(194, 28),
						fit = true,
					}),
					note = e(ToonText, {
						text = "PUNCH 3 DAYS",
						font = "body",
						textSize = 15,
						position = UDim2.fromOffset(72, 28),
						size = UDim2.fromOffset(194, 18),
						fit = true,
					}),
				}),
			}),
			finalReward = e(ToonSurface, {
				hue = "gold",
				small = true,
				radius = 14,
				position = UDim2.fromOffset(318, 246),
				size = UDim2.fromOffset(276, 52),
				children = nodes({
					icon = e(ToonIcon, {
						icon = "gleam",
						position = UDim2.fromOffset(2, -6),
						size = UDim2.fromOffset(62, 58),
						rotation = 10,
					}),
					title = e(ToonText, {
						text = `{Constants.STAR_REWARD} {string.upper(Constants.STAR_LABEL)}`,
						textSize = 22,
						position = UDim2.fromOffset(72, 2),
						size = UDim2.fromOffset(194, 28),
						fit = true,
					}),
					note = e(ToonText, {
						text = "PUNCH 5 DAYS",
						font = "body",
						textSize = 15,
						position = UDim2.fromOffset(72, 28),
						size = UDim2.fromOffset(194, 18),
						fit = true,
					}),
				}),
			}),
			run = label(
				`{props.status.weeks} filled weeks • {Constants.PAYCHEQUE_CREDITS} Credits in {props.status.weeksToPaycheque} filled weeks`,
				302,
				20
			),

			punch = e(ToonButton, {
				text = if props.status.canPunch then "PUNCH TODAY" else "PUNCHED TODAY",
				variant = "primary",
				position = UDim2.fromOffset(22, 328),
				size = UDim2.fromOffset(330, 44),
				disabled = not props.status.canPunch or props.pending == true,
				onActivated = props.onPunch,
			}),
			close = e(ToonButton, {
				text = "CLOSE",
				variant = "secondary",
				position = UDim2.fromOffset(380, 328),
				size = UDim2.fromOffset(220, 44),
				onActivated = props.onClose or props.onToggle,
			}),
		}
		for day, name in DAYS do
			local punched = table.find(props.status.punched, day) ~= nil
			face[`dayTile{day}`] = e(ToonSurface, {
				hue = if punched then "mint" elseif day == props.status.today then "gold" else "lilac",
				small = true,
				radius = 12,
				position = UDim2.fromOffset(24 + (day - 1) * 83, 180),
				size = UDim2.fromOffset(74, 52),
			})
			face[`day{day}`] = e(ToonText, {
				wrapped = true,
				text = `{name}\n{if punched then "PUNCHED" elseif day == props.status.today then "TODAY" else "—"}`,
				font = "body",
				textSize = 14,
				align = "center",
				position = UDim2.fromOffset(24 + (day - 1) * 83, 181),
				size = UDim2.fromOffset(74, 44),
				zIndex = 3,
				fit = true,
				color = UIToonConstants.COLOR.ink,
			})
		end
		if props.view == "workOrder" then
			face = workOrderFace(props)
		end
		children.card = e(CardScale, {
			factor = if props.phone then 0.9 else 1,
			content = {
				header = e(ToonSurface, {
					hue = "grape",
					pattern = "bubbles",
					radius = 22,
					size = UDim2.new(1, 0, 0, 62),
					zIndex = 4,
					children = nodes({
						icon = e(ToonIcon, {
							icon = if props.view == "workOrder" then "jobs" else "clock",
							position = UDim2.fromOffset(-16, -18),
							size = UDim2.fromOffset(100, 94),
							rotation = -10,
							zIndex = 3,
						}),
						title = e(ToonText, {
							text = if props.view == "workOrder" then "DAILY WORK ORDER" else "YOUR TIMECARD",
							textSize = 36,
							position = UDim2.fromOffset(92, 8),
							size = UDim2.new(1, -112, 0, 42),
							fit = true,
						}),
					}),
				}),
				tabs = e("Frame", {
					Size = UDim2.new(1, -44, 0, 34),
					Position = UDim2.fromOffset(22, 78),
					BackgroundTransparency = 1,
					ZIndex = 5,
				}, {
					timecard = e(ToonButton, {
						text = "TIMECARD",
						textSize = 22,
						variant = "secondary",
						selected = props.view ~= "workOrder",
						size = UDim2.new(0.5, -6, 1, 0),
						onActivated = props.onTimecard or props.onToggle,
					}),
					daily = e(ToonButton, {
						text = "DAILY WORK ORDER",
						textSize = 22,
						variant = "secondary",
						selected = props.view == "workOrder",
						position = UDim2.new(0.5, 6, 0, 0),
						size = UDim2.new(0.5, -6, 1, 0),
						onActivated = props.onWorkOrder or props.onToggle,
					}),
				}),
				card = e(ToonSurface, {
					hue = "cream",
					pattern = "sparkle",
					radius = 24,
					size = UDim2.fromScale(1, 1),
					children = face,
				}),
			},
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 }, children)
end
return Panel
