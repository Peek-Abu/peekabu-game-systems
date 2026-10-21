--!strict
--[=[
	ShiftCrewList: the crew in a shift (V1 shift renders): a small dark plate with a row per crew member, their own
	character's head (CharacterPortrait), their name, their Gloom-life hearts (ShiftLivesPips) at the row's right (OUT takes their place for a member knocked out for the shift; the local player's name is gold) and, on a row without lives, a sticker for what matters at a glance (YOU in gold, CAUGHT in
	coral; a caught member's name is struck through and faded). Every pill is as wide as its measured label
	(TextService, ToonStyleViewModel.pillWidth), so no label is ever cut, and the name keeps clear of the tag's column.
	Tapping it opens the detail (`open`): each member's status in words, beside it. Desktop: top-left under Roblox's buttons. Phone: top-right. Presentational (exempt;
	story in ShiftCompactHudPanel.story; the roster is specced in ShiftCrewViewModel).

	@class ShiftCrewList
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local React = require(ReplicatedStorage.Packages.React)
local CharacterPortrait = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.CharacterPortrait)
local ShiftCrewViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftCrewViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local ShiftLivesPips = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftLivesPips)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

-- The side padding of the roster's small pills (the tag).
local PILL_PAD = 7
-- Luckiest Guy label widths in design px (the HUD scales them with everything else), measured once per label.
local measured: { [string]: number } = {}

-- The width of a small pill whose label is `text` at `textSize` with `pad` px of side padding.
local function pillWidth(text: string, textSize: number, pad: number): number
	local key = `{textSize}:{text}`
	local width = measured[key]
	if width == nil then
		width = TextService:GetTextSize(text, textSize, Enum.Font.LuckiestGuy, Vector2.new(10000, 1000)).X
		measured[key] = width
	end
	return ToonStyleViewModel.pillWidth(width, textSize, pad)
end

export type ShiftCrewListProps = {
	roster: ShiftCrewViewModel.RosterView,
	myId: number,
	phone: boolean,
	position: UDim2,
	anchor: Vector2,
	onToggle: (() -> ())?,
	-- The phone's list width on a narrow screen (ShiftCrewViewModel.phoneFit); nil is the design width.
	width: number?,
}

local function row(member: ShiftCrewViewModel.MemberView, you: boolean, phone: boolean, width: number, order: number)
	local height = (if phone then ShiftCrewViewModel.LIST.phone else ShiftCrewViewModel.LIST.desktop).row
	local roomy = height > 34
	-- With Gloom lives (none for a member not in a shift) the right column holds the hearts, or OUT in their place, and
	-- the local player is marked by a gold name; without them the tag (OUT, CAUGHT or YOU) sits at the name's right.
	local lives, livesMax = member.lives, member.livesMax
	local hasLives = lives ~= nil and livesMax ~= nil
	local tag = if member.out
		then "OUT"
		elseif hasLives then nil
		elseif member.tone == "danger" then "CAUGHT"
		elseif you then "YOU"
		else nil
	local tagSize = if roomy then 14 else 12
	local tagPad = if hasLives then ShiftCrewViewModel.OUT_PAD else PILL_PAD
	local tagWidth = if tag ~= nil then pillWidth(tag, tagSize, tagPad) else 0
	local layout = ShiftCrewViewModel.rowLayout(phone, width, tagWidth, if hasLives then livesMax else nil)
	local sizes = if roomy then ShiftHudViewModel.LIVES.desktop else ShiftHudViewModel.LIVES.phone
	local nameWidth = layout.nameWidth
	local avatar = layout.avatar
	local lineX = layout.nameX
	local tagHeight = if roomy then 24 else 20
	local nameColor = if you and hasLives then UIToonConstants.shade("gold").base else COLOR.white
	local children: { [string]: React.ReactNode } = {
		face = if layout.face
			then e("Frame", {
				Position = UDim2.fromOffset(0, 4),
				Size = UDim2.fromOffset(avatar, avatar),
				BackgroundColor3 = UIToonConstants.shade("lilac").hi,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				stroke = e(
					"UIStroke",
					{ Color = if you then COLOR.selected else COLOR.ink, Thickness = ShiftCrewViewModel.FACE_OUTLINE }
				),
				-- Their own character's head (a caught one worried and greyed).
				portrait = e(CharacterPortrait, {
					userId = member.userId,
					context = if member.struck then "caught" else "crew",
					framing = "head",
					size = UDim2.fromScale(1, 1),
					round = true,
					dim = member.struck,
				}),
			})
			else nil,
		name = e(ToonText, {
			text = member.name,
			font = "body",
			color = nameColor,
			textSize = if roomy then 19 else 15,
			position = UDim2.fromOffset(lineX, 0),
			size = UDim2.fromOffset(nameWidth, height),
			fit = true,
			transparency = if member.struck then 0.45 else 0,
		}),
	}
	if member.struck then
		children.strike = e("Frame", {
			Position = UDim2.new(0, lineX, 0.5, 0),
			Size = UDim2.fromOffset(math.min(nameWidth, 8 + #member.name * 9), 2),
			BackgroundColor3 = COLOR.white,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		})
	end
	if lives ~= nil and livesMax ~= nil and not member.out then
		children.lives = ShiftLivesPips.pips({
			lives = lives,
			livesMax = livesMax,
			sizes = sizes,
			position = UDim2.fromOffset(layout.columnX or 0, (height - sizes.pip - 2 * sizes.stroke) / 2),
		})
	end
	if tag ~= nil then
		children.tag = e(ToonPill, {
			text = tag,
			hue = if tag == "YOU" then "gold" else "coral",
			textSize = tagSize,
			padX = tagPad,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -2, 0.5, 0),
			size = UDim2.fromOffset(tagWidth, tagHeight),
			tilt = if tag == "YOU" then -3 else 3,
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
	local list = if phone then ShiftCrewViewModel.LIST.phone else ShiftCrewViewModel.LIST.desktop
	local padding = list.padding
	local members = props.roster.members
	local size = ShiftCrewViewModel.listSize(phone, #members, props.width)
	local width, height = size.X, size.Y
	local rows: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	}
	for index, member in members do
		rows[`m{index}`] = row(member, member.userId == props.myId, phone, width - 2 * padding, index)
	end
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
