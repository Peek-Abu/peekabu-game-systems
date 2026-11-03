--!strict
--[=[
	AbilityButton: the employee's ability button in the V1 kit, a round plate on the depth stack like the phone's action
	arc (ShiftActionButton): the ability's icon on it, mint and glossed while ready, gold while its effect runs, night
	while it cools down, with a dark sweep over the icon that drains as the cooldown runs and the seconds left in big
	stroked numbers. A cream key cap names the key (Q, or Y on a gamepad; none on a touch screen, where a tap uses it),
	and "Ready!" pops over it the moment it is ready again. On a phone it sits on the action arc (right above CROUCH);
	on a desktop bottom right. A tap or click asks the server (`onUse`, from AbilityServiceClient, so this module never
	requires the service that registers it); the server decides.

	A HUD widget `Widget` (reads AbilityStore, the shift, the scare beat and the server clock, and draws what
	AbilityViewModel.button decides) around the presentational `AbilityButton` (exempt; story in
	AbilityButton.story).

	@class AbilityButton
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local AbilityStore = require(ReplicatedStorage.Client.Features.Ability.State.AbilityStore)
local OccupantCatchStore = require(ReplicatedStorage.Client.Features.Occupant.State.OccupantCatchStore)
local ShiftStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local useServerClock = require(ReplicatedStorage.Client.UI.React.Hooks.useServerClock)
local usePaperViewport = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperViewport)
local AbilityViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Ability.AbilityViewModel)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPose = require(Toon.useToonPose)

local e = React.createElement
local useAtom = ReactCharm.useAtom

export type AbilityButtonProps = {
	view: AbilityViewModel.ButtonView,
	onUse: (() -> ())?,
}

-- How long "Ready!" shows once the ability is ready again (seconds).
local READY_POP = 1.2
-- The cooldown sweep's darkness over the icon.
local SWEEP_TRANSPARENCY = 0.35
local KEY_SIZE = 30

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function AbilityButton(props: AbilityButtonProps): React.ReactNode
	local view = props.view
	local onUse = props.onUse
	local pressed, setPressed = React.useState(false)
	local popping, setPopping = React.useState(false)
	local wasReady = React.useRef(view.ready)
	React.useEffect(function()
		local before = wasReady.current
		wasReady.current = view.ready
		if view.ready and before == false then
			setPopping(true)
			local thread = task.delay(READY_POP, function()
				setPopping(false)
			end)
			return function()
				task.cancel(thread)
			end
		end
		return function() end
	end, { view.ready })
	local hue: UIToonConstants.Hue = if view.active then "gold" elseif view.ready then "mint" else "night"
	local pose = useToonPose(
		ToonStyleViewModel.pose({
			hovered = false,
			pressed = pressed,
			selected = view.active,
			disabled = false,
			receded = false,
		}),
		if pressed then UIToonConstants.MOTION.pressSeconds else UIToonConstants.MOTION.hoverSeconds
	)
	local spot = view.spot
	local image = UIAssets.iconImage(view.icon)
	local face: { [string]: React.ReactNode } = {
		icon = if image ~= nil
			then e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.78, 0.78),
				BackgroundTransparency = 1,
				Image = image,
				ScaleType = Enum.ScaleType.Fit,
			})
			else nil,
		-- The cooldown sweep: a dark disc over the icon that drains from the top as the cooldown runs.
		sweep = if view.remaining > 0
			then e("CanvasGroup", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				GroupTransparency = SWEEP_TRANSPARENCY,
				ZIndex = 2,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				dark = e("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.fromScale(1, view.remaining),
					BackgroundColor3 = UIToonConstants.shade("night").lo,
					BorderSizePixel = 0,
				}),
			})
			else nil,
		seconds = if view.seconds ~= nil
			then e(ToonText, {
				text = view.seconds,
				textSize = math.floor(spot.size * 0.38),
				size = UDim2.fromScale(1, 1),
				align = "center",
				zIndex = 3,
			})
			else nil,
	}
	local keyFace: { [string]: React.ReactNode } = {
		label = e(ToonText, {
			text = view.key or "",
			textSize = 18,
			font = "body",
			size = UDim2.fromScale(1, 1),
			align = "center",
		}),
	}
	return e("TextButton", {
		Position = UDim2.new(1, spot.x, 1, spot.y),
		Size = UDim2.fromOffset(spot.size, spot.size),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		[React.Event.InputBegan] = function(_button: TextButton, input: InputObject)
			if isPress(input) then
				setPressed(true)
			end
		end,
		[React.Event.InputEnded] = function(_button: TextButton, input: InputObject)
			if isPress(input) then
				setPressed(false)
			end
		end,
		[React.Event.MouseLeave] = function()
			setPressed(false)
		end,
		[React.Event.Activated] = function()
			if onUse ~= nil then
				onUse()
			end
		end,
	}, {
		plate = e(ToonSurface, {
			hue = hue,
			radius = 999,
			pose = pose,
			gloss = view.ready or view.active,
			size = UDim2.fromScale(1, 1),
			children = face,
		}),
		key = if view.key ~= nil
			then e(ToonSurface, {
				hue = "cream",
				radius = 8,
				small = true,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.new(1, -8, 0, 8),
				size = UDim2.fromOffset(KEY_SIZE, KEY_SIZE),
				zIndex = 4,
				children = keyFace,
			})
			else nil,
		ready = if popping
			then e(ToonText, {
				text = "Ready!",
				textSize = 20,
				meaning = "gold",
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 0, -6),
				size = UDim2.fromOffset(spot.size + 40, 26),
				align = "center",
				zIndex = 5,
			})
			else nil,
	})
end

local function isGamepad(input: Enum.UserInputType): boolean
	return input.Name:sub(1, 7) == "Gamepad"
end

export type WidgetProps = {
	onUse: (() -> ())?,
}

-- The HUD widget: reads the stores and the server clock, draws what AbilityViewModel.button decides.
local function Widget(props: WidgetProps?): React.ReactNode
	local snapshot = useAtom(ShiftStore.snapshot)
	local publicPlayers = useAtom(StateSyncClientStore.publicPlayers)
	local scaring = useAtom(OccupantCatchStore.scaring)
	local abilityId = useAtom(AbilityStore.abilityId)
	local readyAt = useAtom(AbilityStore.readyAt)
	local active = useAtom(AbilityStore.active)
	local gamepad, setGamepad = React.useState(isGamepad(UserInputService:GetLastInputType()))
	React.useEffect(function()
		local changed = UserInputService.LastInputTypeChanged:Connect(function(input: Enum.UserInputType)
			setGamepad(isGamepad(input))
		end)
		return function()
			changed:Disconnect()
		end
	end, {})
	local viewport = usePaperViewport()
	local player = Players.LocalPlayer
	local me = if player ~= nil then publicPlayers[StateSyncConstants.publicEntryKey(player.UserId)] else nil
	-- The clock ticks only while a cooldown counts down.
	local now = useServerClock(0.25, abilityId ~= nil and readyAt > 0)
	local view = AbilityViewModel.button({
		abilityId = abilityId,
		phase = if snapshot ~= nil then snapshot.phase else nil,
		hidden = ShiftHudViewModel.hidden(me, scaring),
		readyAt = readyAt,
		active = active,
		now = now,
		touch = UserInputService.TouchEnabled,
		gamepad = gamepad,
		shortSide = math.min(viewport.X, viewport.Y),
	})
	if view == nil then
		return nil
	end
	return e(AbilityButton, { view = view, onUse = if props ~= nil then props.onUse else nil })
end

return {
	AbilityButton = AbilityButton,
	Widget = Widget,
}
