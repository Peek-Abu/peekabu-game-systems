--!strict
--[=[
	ShiftPromptChip: the paper interaction prompt (Figma 1a "Prompt": "[E] LOAD monitor onto the truck"), drawn for the
	Interaction prompt the engine is showing (ShiftPromptStore; the engine's own card is off, see ShiftPromptSystem). A
	cream slip taped on at a slight tilt, centred below the crosshair: a KeyChip with the prompt's key and the words; a
	hold prompt fills an ink-green strip under the words while it is held. On phone (Figma 1d) it is a narrower slip
	high in the screen, without the key (there is no keyboard).

	The whole slip is a button: pressing it holds the prompt and releasing (or sliding off) lets go, through the
	`onPress` prop (ShiftServiceClient registers this widget with ShiftPromptSystem.press: a prop, so this module never
	requires the service that registers it). That is the touch path; a keyboard key goes to the engine directly.

	A HUD widget: it reads the stores and draws what ShiftHudViewModel.prompt decides (nil when nothing is shown, or
	while the HUD is hidden).

	@class ShiftPromptChip
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local KeyChip = require(ReplicatedStorage.Client.UI.React.Screens.Paper.KeyChip)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperLayout = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperLayout)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local e = React.createElement
local useAtom = ReactCharm.useAtom

export type ShiftPromptChipProps = {
	-- Holds (true) or releases (false) the shown prompt.
	onPress: ((down: boolean) -> ())?,
}

type Geometry = {
	position: UDim2,
	size: Vector2,
	padding: number,
	text: number,
}

local COLOR = UIPaperConstants.COLOR
-- Figma 1a "Prompt": 460x64, centred, top at 0.6 of the screen; 1d: 280 wide at y 236 on phone.
local GEOMETRY: { [UIPaperConstants.Layout]: Geometry } = table.freeze({
	desktop = table.freeze({
		position = UDim2.fromScale(0.5, 0.6),
		size = Vector2.new(460, 64),
		padding = 12,
		text = UIPaperConstants.TEXT.desktop.body,
	}),
	phone = table.freeze({
		position = UDim2.new(0.5, 0, 0, 236),
		size = Vector2.new(280, 44),
		padding = 8,
		text = UIPaperConstants.TEXT.phone.body,
	}),
})
local KEY_SIZE = 24
local KEY_GAP = 12
local STRIP_HEIGHT = 4
-- The server clock ticks fast only while a hold fills the strip.
local HOLD_TICK = 0.05
local IDLE_TICK = 0.25

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- The hold strip: a faint ink track with the ink-green fill, just under the words.
local function strip(fill: number, inset: number): React.ReactNode
	return e("Frame", {
		Position = UDim2.new(0, inset, 1, 2),
		Size = UDim2.new(1, -inset, 0, STRIP_HEIGHT),
		BackgroundColor3 = COLOR.ink,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
	}, {
		fill = e("Frame", {
			Size = UDim2.fromScale(fill, 1),
			BackgroundColor3 = COLOR.inkGreen,
			BorderSizePixel = 0,
		}),
	})
end

local function ShiftPromptChip(props: ShiftPromptChipProps?): React.ReactNode
	local shown = useAtom(ShiftPromptStore.shown)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	local layout: UIPaperConstants.Layout = usePaperLayout()
	local now = useServerClock(if shown ~= nil and shown.holdStartedAt ~= nil then HOLD_TICK else IDLE_TICK)
	local onPress = if props ~= nil then props.onPress else nil
	-- Whether this chip started a hold that has not been released yet.
	local pressing = React.useRef(false)
	local press = React.useCallback(function(down: boolean)
		if onPress == nil or pressing.current == down then
			return
		end
		pressing.current = down
		onPress(down)
	end, { onPress })
	-- A chip that goes away mid-press (the prompt hid) never sees its InputEnded: let go here.
	React.useEffect(function()
		return function()
			press(false)
		end
	end, { press })

	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	local carrying = if me ~= nil then me[CarryConstants.PUBLIC_FIELD] else nil
	local chip = ShiftHudViewModel.prompt(shown, carrying, now, ShiftHudViewModel.hidden(me, scaring))
	if chip == nil then
		return nil
	end
	local geometry = GEOMETRY[layout]
	local desktop = layout == "desktop"
	local textInset = if desktop then KEY_SIZE + 10 + KEY_GAP else 0
	local fill = chip.fill
	local content: { [string]: React.ReactNode } = {
		text = e(PaperLabel, {
			text = chip.text,
			role = "body",
			size = geometry.text,
			color = COLOR.ink,
			position = UDim2.fromOffset(textInset, 0),
			frame = UDim2.new(1, -textInset, 1, 0),
			align = if desktop then "left" else "center",
			autoSize = false,
			wrapped = false,
		}),
	}
	if desktop then
		content.key = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(0, KEY_SIZE + 10),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
		}, { chip = e(KeyChip, { label = chip.key, size = KEY_SIZE }) })
	end
	if fill ~= nil then
		content.strip = strip(fill, textInset)
	end
	return e("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = geometry.position,
		Size = UDim2.fromOffset(geometry.size.X, geometry.size.Y),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		[React.Event.InputBegan] = function(_button: TextButton, input: InputObject)
			if isPress(input) then
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
	}, {
		slip = e(PaperSheet, {
			size = UDim2.fromScale(1, 1),
			paper = COLOR.cream,
			tilt = -1,
			fastener = "tape",
			padding = geometry.padding,
			children = content,
		}),
	})
end

return ShiftPromptChip
