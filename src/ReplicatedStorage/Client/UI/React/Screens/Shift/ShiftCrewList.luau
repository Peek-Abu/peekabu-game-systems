--!strict
--[=[
	ShiftCrewList: the crew in a shift (V1 shift renders): a small dark plate with a row per crew member, their own
	character's head (CharacterPortrait), their name and a sticker for what matters at a glance (YOU in gold, CAUGHT in
	coral; a caught member's name is struck through and faded). Tapping it opens the detail (`open`): each member's
	status in words, beside it. Desktop: top-left under Roblox's buttons. Phone: top-right. Presentational (exempt;
	story in ShiftCompactHudPanel.story; the roster is specced in ShiftCrewViewModel).

	@class ShiftCrewList
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CharacterPortrait = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.CharacterPortrait)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type ShiftCrewListProps = {
	roster: ShiftCrewViewModel.RosterView,
	myId: number,
	phone: boolean,
	position: UDim2,
	anchor: Vector2,
	onToggle: (() -> ())?,
}

local function row(member: ShiftCrewViewModel.MemberView, you: boolean, height: number, width: number, order: number)
	local avatar = height - 8
	local children: { [string]: React.ReactNode } = {
		face = e("Frame", {
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.fromOffset(avatar, avatar),
			BackgroundColor3 = UIToonConstants.shade("lilac").hi,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = if you then COLOR.selected else COLOR.ink, Thickness = 3 }),
			-- Their own character's head (a caught one worried and greyed).
			portrait = e(CharacterPortrait, {
				userId = member.userId,
				context = if member.struck then "caught" else "crew",
				framing = "head",
				size = UDim2.fromScale(1, 1),
				round = true,
				dim = member.struck,
			}),
		}),
		name = e(ToonText, {
			text = member.name,
			font = "body",
			color = COLOR.white,
			textSize = if height > 34 then 19 else 15,
			position = UDim2.fromOffset(avatar + 8, 0),
			size = UDim2.fromOffset(width - avatar - 8 - 66, height),
			fit = true,
			transparency = if member.struck then 0.45 else 0,
		}),
	}
	if member.struck then
		children.strike = e("Frame", {
			Position = UDim2.new(0, avatar + 8, 0.5, 0),
			Size = UDim2.fromOffset(math.min(width - avatar - 80, 8 + #member.name * 9), 2),
			BackgroundColor3 = COLOR.white,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		})
	end
	local tag = if member.tone == "danger" then "CAUGHT" elseif you then "YOU" else nil
	if tag ~= nil then
		children.tag = e(ToonPill, {
			text = tag,
			hue = if tag == "YOU" then "gold" else "coral",
			textSize = if height > 34 then 14 else 11,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.fromScale(1, 0.5),
			size = UDim2.fromOffset(if tag == "YOU" then 50 else 66, if height > 34 then 24 else 20),
			tilt = if tag == "YOU" then -4 else 3,
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, children)
end

local function ShiftCrewList(props: ShiftCrewListProps): React.ReactNode
	local phone = props.phone
	local rowHeight = if phone then 28 else 40
	local width = if phone then 176 else 236
	local padding = if phone then 8 else 12
	local members = props.roster.members
	local rows: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	}
	for index, member in members do
		rows[`m{index}`] = row(member, member.userId == props.myId, rowHeight, width - 2 * padding, index)
	end
	local height = 2 * padding + #members * (rowHeight + 2)
	local body: { [string]: React.ReactNode } = {
		rows = e("Frame", {
			Position = UDim2.fromOffset(padding, padding),
			Size = UDim2.new(1, -2 * padding, 1, -2 * padding),
			BackgroundTransparency = 1,
		}, rows),
	}
	local onToggle = props.onToggle
	return e("TextButton", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		[React.Event.Activated] = function()
			if onToggle ~= nil then
				onToggle()
			end
		end,
	}, {
		plate = e(ToonPanel, {
			hue = "night",
			size = Vector2.new(width, height),
			radius = if phone then 16 else 22,
			children = body,
		}),
	})
end

return ShiftCrewList
