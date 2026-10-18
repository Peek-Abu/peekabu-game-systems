--!strict
--[=[
	ShiftPromptChip: the interaction prompt in the V1 kit ("[E] PICK UP Desk Monitor"), drawn for the Interaction
	prompt the engine is showing (ShiftPromptStore; the engine's own card is off, see ShiftPromptSystem). A cream pill
	on the depth stack, centred below the crosshair: a key cap with the prompt's key and the words; a hold prompt fills
	a mint bar under the words while it is held. On phone it is a narrower pill high in the screen, without the key
	(there is no keyboard).

	On a touch device without a keyboard the whole slip is a touch button (elsewhere a plain Frame, so it never sinks a
	mouse click): a touch holds the prompt and lifting (or sliding off) lets go, through the
	`onPress` prop (ShiftServiceClient registers this widget with ShiftPromptSystem.press: a prop, so this module never
	requires the service that registers it). Mouse clicks pass through (LMB is the vacuum); a keyboard key goes to the
	engine directly.

	A HUD widget: it reads the stores and draws what ShiftHudViewModel.prompt decides (nil when nothing is shown, or
	while the HUD is hidden).

	@class ShiftPromptChip
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local PaperHudFrame = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperHudFrame)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)
local ToonPanel = require(Toon.ToonPanel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperHudScale = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperHudScale)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)

local useProgressTween = require(ReplicatedStorage.Client.UI.React.Hooks.useProgressTween)

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

-- Desktop: centred above the hotbar; phone: high in the screen, clear of the thumbstick and the action arc.
local GEOMETRY: { [UIPaperConstants.Layout]: Geometry } = table.freeze({
	desktop = table.freeze({
		position = UDim2.new(0.5, 0, 1, -140),
		size = Vector2.new(380, 52),
		padding = 12,
		text = 18,
	}),
	phone = table.freeze({
		position = UDim2.new(0.5, 0, 0, 236),
		size = Vector2.new(250, 54),
		padding = 10,
		text = UIPaperConstants.TEXT.phone.body,
	}),
})
local KEY_SIZE = 34
local KEY_GAP = 12
local STRIP_HEIGHT = 4
-- The server clock ticks only while a hold fills the strip.
local HOLD_TICK = 0.05

-- Only a touch presses the slip: a mouse button is the vacuum (LMB) and a keyboard player presses the prompt's key.
local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch
end

-- The hold bar: a mint fill just under the words.
local function strip(fill: React.Binding<number>, inset: number): React.ReactNode
	return e(ToonBar, {
		kind = "xp",
		fill = fill,
		position = UDim2.new(0, inset, 1, -2),
		size = UDim2.new(1, -inset, 0, STRIP_HEIGHT + 6),
	})
end

local function ShiftPromptChip(props: ShiftPromptChipProps?): React.ReactNode
	local keyWidth = KEY_SIZE + 4
	local shown = useAtom(ShiftPromptStore.shown)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	-- The desktop chip is drawn scaled to the window, with the rest of the HUD (PaperHudFrame).
	local hudScale = usePaperHudScale()
	local layout: UIPaperConstants.Layout = hudScale.layout
	-- Only a hold's fill changes with time; an idle prompt does not follow the clock.
	local now = useServerClock(HOLD_TICK, shown ~= nil and shown.holdStartedAt ~= nil)
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

	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	local carrying = if me ~= nil then me[CarryConstants.PUBLIC_FIELD] else nil
	local chip = ShiftHudViewModel.prompt(shown, carrying, now, ShiftHudViewModel.hidden(me, scaring))
	-- The prompt the slip is drawn for (0: none). Returning nil keeps this widget mounted, so a slip that goes away
	-- mid-press (the prompt hid, a newer one showed, the HUD hid) never sees its InputEnded: let go when it changes.
	local drawnId = if chip ~= nil and shown ~= nil then shown.id else 0
	React.useEffect(function()
		return function()
			press(false)
		end
	end, { drawnId })
	local holdStart = if shown ~= nil then shown.holdStartedAt else nil
	local progress =
		useProgressTween(if chip ~= nil then chip.fill or 0 else 0, HOLD_TICK, `{drawnId}/{holdStart or 0}`, true)
	if chip == nil then
		return nil
	end
	local geometry = GEOMETRY[layout]
	local desktop = layout == "desktop"
	local textInset = if desktop then keyWidth + KEY_GAP else 0
	local fill = chip.fill
	local content: { [string]: React.ReactNode } = {
		text = e(ToonText, {
			text = chip.text,
			font = "body",
			textSize = geometry.text,
			position = UDim2.fromOffset(textInset, 0),
			size = UDim2.new(1, -textInset, 1, if fill ~= nil then -6 else 0),
			align = if desktop then "left" else "center",
			wrapped = not desktop,
			fit = true,
		}),
	}
	if desktop then
		local cap: { [string]: React.ReactNode } = {}
		cap.key = e(ToonText, {
			text = chip.key,
			textSize = 20,
			size = UDim2.fromScale(1, 1),
			align = "center",
			fit = true,
		})
		content.key = e(ToonSurface, {
			hue = "cream",
			small = true,
			radius = 9,
			anchor = Vector2.new(0, 0.5),
			position = UDim2.fromScale(0, 0.5),
			size = UDim2.fromOffset(KEY_SIZE, KEY_SIZE),
			children = cap,
		})
	end
	if fill ~= nil then
		content.strip = strip(progress, textInset)
	end
	local inner: { [string]: React.ReactNode } = {
		content = e("Frame", {
			Position = UDim2.fromOffset(geometry.padding, 6),
			Size = UDim2.new(1, -2 * geometry.padding, 1, -12),
			BackgroundTransparency = 1,
		}, content),
	}
	local slip = e(ToonPanel, {
		hue = if shown ~= nil and shown.holdStartedAt ~= nil then "gold" else "cream",
		size = geometry.size,
		radius = 20,
		children = inner,
	})
	local size = UDim2.fromOffset(geometry.size.X, geometry.size.Y)
	if not ShiftHudViewModel.promptTouchable(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled) then
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
	}, { slip = slip })
	return e(PaperHudFrame, { scale = 1, children = { chip = button } })
end

return ShiftPromptChip
