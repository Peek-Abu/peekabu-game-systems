--!strict
--[=[
	HideChip: the hiding spot's paper prompt (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md §4),
	the same taped cream slip as the interaction chip, one slot above it so both can show ("[E] SEARCH desk" and
	"[C] HIDE UNDER desk"). Going in is a single press; inside a spot the chip is the way out ("[C] LEAVE desk"), a
	manila warning once the stay is cramped. On a touch screen the slip is the button: a tap presses the prompt, or
	leaves while hidden (the `onPress` / `onLeave` props, from HideServiceClient, so this module never requires the
	service that registers it).

	A HUD widget: it reads HideStore and draws what HideViewModel.chip decides.

	@class HideChip
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local HideStore = require(ReplicatedStorage.Client.Features.Hide.State.HideStore)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local useProgressTween = require(ReplicatedStorage.Client.UI.React.Hooks.useProgressTween)
local KeyChip = require(ReplicatedStorage.Client.UI.React.Screens.Paper.KeyChip)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local HideViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Hide.HideViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

export type HideChipProps = {
	-- Holds (true) or releases (false) the shown hiding prompt.
	onPress: ((down: boolean) -> ())?,
	-- Comes out of the spot.
	onLeave: (() -> ())?,
}

type Geometry = { position: UDim2, size: Vector2, padding: number, text: number }

local COLOR = UIPaperConstants.COLOR
-- One slot above the interaction chip (desktop: its top at 1,-122; phone: at 0,236).
local GEOMETRY: { [UIPaperConstants.Layout]: Geometry } = table.freeze({
	desktop = table.freeze({
		position = UDim2.new(0.5, 0, 1, -176),
		size = Vector2.new(300, 42),
		padding = 10,
		text = 14,
	}),
	phone = table.freeze({
		position = UDim2.new(0.5, 0, 0, 170),
		size = Vector2.new(220, 52),
		padding = 8,
		text = UIPaperConstants.TEXT.phone.body,
	}),
})
local KEY_SIZE = 16
local KEY_GAP = 12
local HOLD_TICK = 0.05
local IDLE_TICK = 0.25

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch
end

local function HideChip(props: HideChipProps?): React.ReactNode
	local keyWidth, setKeyWidth = React.useState(KEY_SIZE + 26)
	local prompt = useAtom(HideStore.prompt)
	local hidden = useAtom(HideStore.hidden)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	local hudScale = usePaperHudScale()
	local layout: UIPaperConstants.Layout = hudScale.layout
	local holding = prompt ~= nil and prompt.holdStartedAt ~= nil
	local now = useServerClock(if holding or hidden ~= nil then HOLD_TICK else IDLE_TICK)
	local onPress = if props ~= nil then props.onPress else nil
	local onLeave = if props ~= nil then props.onLeave else nil
	local pressing = React.useRef(false)
	local press = React.useCallback(function(down: boolean)
		if onPress == nil or pressing.current == down then
			return
		end
		pressing.current = down
		onPress(down)
	end, { onPress })
	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	local caught = me ~= nil and me[DeathConstants.PUBLIC_FIELD] == true
	local chip = HideViewModel.chip(prompt, hidden, HideConstants.KEYBOARD_KEY.Name, now, scaring or caught)
	local drawnId = if hidden ~= nil then -1 elseif prompt ~= nil then prompt.id else 0
	React.useEffect(function()
		return function()
			press(false)
		end
	end, { drawnId })
	local progress = useProgressTween(
		if chip ~= nil then chip.fill or 0 else 0,
		HOLD_TICK,
		`{drawnId}/{if prompt ~= nil then prompt.holdStartedAt or 0 else 0}`,
		true
	)
	if chip == nil then
		return nil
	end
	local geometry = GEOMETRY[layout]
	local desktop = layout == "desktop"
	local textInset = if desktop then keyWidth + KEY_GAP else 0
	local content: { [string]: React.ReactNode } = {
		text = e(PaperLabel, {
			text = chip.text,
			role = "body",
			size = geometry.text,
			color = if chip.warn then COLOR.stamp else COLOR.ink,
			position = UDim2.fromOffset(textInset, 0),
			frame = UDim2.new(1, -textInset, 1, 0),
			align = if desktop then "left" else "center",
			autoSize = false,
			wrapped = not desktop,
		}),
	}
	if desktop then
		content.key = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(0, KEY_SIZE + 10),
			AutomaticSize = Enum.AutomaticSize.X,
			[React.Change.AbsoluteSize] = function(frame: Frame)
				setKeyWidth(frame.AbsoluteSize.X)
			end,
			BackgroundTransparency = 1,
		}, { chip = e(KeyChip, { label = chip.key, size = KEY_SIZE }) })
	end
	if chip.fill ~= nil then
		content.strip = e("Frame", {
			Position = UDim2.new(0, textInset, 1, 2),
			Size = UDim2.new(1, -textInset, 0, 4),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
		}, {
			fill = e("Frame", {
				Size = progress:map(function(fraction: number): UDim2
					return UDim2.fromScale(fraction, 1)
				end),
				BackgroundColor3 = COLOR.companyTeal,
				BorderSizePixel = 0,
			}),
		})
	end
	local slip = e(PaperSheet, {
		size = UDim2.fromScale(1, 1),
		paper = if chip.warn or holding then COLOR.manila else COLOR.cream,
		tilt = 1,
		fastener = "tape",
		padding = geometry.padding,
		children = content,
	})
	local size = UDim2.fromOffset(geometry.size.X, geometry.size.Y)
	if not UserInputService.TouchEnabled then
		-- Not a button: a GuiButton would sink the mouse click under it (the vacuum is LMB).
		return e(PaperHudFrame, {
			scale = 1,
			children = {
				chip = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = geometry.position,
					Size = size,
					BackgroundTransparency = 1,
				}, { slip = slip }),
			},
		})
	end
	local button = e("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = geometry.position,
		Size = size,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		[React.Event.InputBegan] = function(_button: TextButton, input: InputObject)
			if not isPress(input) then
				return
			end
			if hidden ~= nil then
				if onLeave ~= nil then
					onLeave()
				end
			else
				press(true)
			end
		end,
		[React.Event.InputEnded] = function(_button: TextButton, input: InputObject)
			if isPress(input) then
				press(false)
			end
		end,
		[React.Event.MouseLeave] = function()
			press(false)
		end,
	}, { slip = slip })
	return e(PaperHudFrame, { scale = 1, children = { chip = button } })
end

return HideChip
