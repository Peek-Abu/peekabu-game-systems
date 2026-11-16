--!strict
--[=[
	DepotTimecardFace: the TIMECARD sheet of the Company Clipboard (DepotTimecardPanel). A track of punch slots (done
	in gold with a tick, today's in mint with a ring, the rest empty), the Gloom Key hung under the key punch and the
	Gleam under the last, a big PUNCH IN! (its border pulses gold while today's punch is free), the paycheck as a row
	of dots (one per full week), and today's punch landing (DepotTimecardStamp) while it shows. Layout and words come
	from the specced DepotClipboardViewModel. Split out of DepotTimecardPanel.

	@class DepotTimecardFace
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Rules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local Constants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonSurface = require(Toon.ToonSurface)
local ToonButton = require(Toon.ToonButton)
local ToonText = require(Toon.ToonText)
local ToonIcon = require(Toon.ToonIcon)
local ToonHighlight = require(Toon.ToonHighlight)
local UIToonConstants = require(Toon.UIToonConstants)
local TimecardMomentUtils = require(ReplicatedStorage.Client.Features.Timecard.Utils.TimecardMomentUtils)
local DepotTimecardStamp = require(script.Parent.DepotTimecardStamp)
local VM = require(script.Parent.DepotClipboardViewModel)
local e = React.createElement
local COLOR = UIToonConstants.COLOR
-- What the sheet reads of the panel's props (DepotTimecardPanel.Props).
export type Props = {
	status: Rules.Status,
	feedback: string,
	pending: boolean?,
	onPunch: () -> (),
	-- Today's punch landing (TimecardMomentStore.stamp): drawn over the Timecard face while it shows.
	stamp: TimecardMomentUtils.Moment?,
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
		-- While today's punch is free the button stays still and only its border gently pulses gold (owner
		-- 2026-11-14), however the Timecard was opened.
		punch = e(ToonHighlight, {
			active = status.canPunch and props.pending ~= true,
			position = UDim2.fromOffset(20, 262),
			size = UDim2.fromOffset(290, 56),
			zIndex = 3,
			children = {
				button = e(ToonButton, {
					text = if status.canPunch then "PUNCH IN!" else "PUNCHED TODAY",
					textSize = 30,
					variant = "primary",
					size = UDim2.fromScale(1, 1),
					disabled = not status.canPunch or props.pending == true,
					onActivated = props.onPunch,
					zIndex = 3,
				}),
			},
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
				position = UDim2.fromOffset(center.X, center.Y + VM.SLOT / 2 + 62),
				size = UDim2.fromOffset(176, 30),
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

return timecardFace
