--!strict
--[=[
	ToonSlider: a value slider in the V1 kit. The track is a ToonBar (deep track, ink outline, inner shadow, the glossy
	capsule fill) on its own hard ink drop; the knob is a cream button on the depth stack that lifts and takes the
	lilac selected ring while it is held, hovered or selected; the value reads on a night pill at the right ("75%").

	Input: press or touch anywhere on the slider to jump the knob there and drag (mouse and touch, followed through
	UserInputService until release, so a drag that leaves the slider keeps working); while hovered, held or selected
	with a gamepad, Left / Right, A / D and the d-pad move one step (bound through ContextActionService at high
	priority and sunk, so the character does not walk and gamepad selection does not leave the slider sideways).
	`onChange` gets every new stepped value (the caller debounces sends: SettingServiceClient sends once a drag ends).
	The knob follows a drag locally and `value` otherwise. Presentational (exempt; story in ToonSlider.story; the value
	maths is specced in ToonSliderViewModel).

	@class ToonSlider
]=]

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)
local ToonPill = require(Toon.ToonPill)
local ToonSliderViewModel = require(Toon.ToonSliderViewModel)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local ToonSurface = require(Toon.ToonSurface)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPose = require(Toon.useToonPose)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH
local MOTION = UIToonConstants.MOTION

export type ToonSliderProps = {
	value: number,
	min: number,
	max: number,
	step: number?,
	onChange: (value: number) -> (),
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	-- The track's fill: "load" (grape, the default) or any ToonBar kind.
	kind: ToonBar.Kind?,
	-- The value pill's text for a value (default: ToonSliderViewModel.percent). The pill is 82 px wide.
	format: ((value: number) -> string)?,
	disabled: boolean?,
	layoutOrder: number?,
	zIndex: number?,
}

-- The knob's diameter, the track's height and the value pill's width (design px).
local KNOB = 40
local TRACK = 22
local PILL = 82
local GAP = 16

local NUDGE_KEYS = {
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.A,
	Enum.KeyCode.D,
	Enum.KeyCode.DPadLeft,
	Enum.KeyCode.DPadRight,
}

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function ToonSlider(props: ToonSliderProps): React.ReactNode
	local min, max, step = props.min, props.max, props.step
	local disabled = props.disabled == true
	local shown, setShown = React.useState(props.value)
	local dragging, setDragging = React.useState(false)
	local hovered, setHovered = React.useState(false)
	local selected, setSelected = React.useState(false)
	-- The track Frame (set by its ref), whose real position and width a pointer is read against.
	local track = React.useMemo(function(): { frame: Frame? }
		return { frame = nil }
	end, {})
	-- The latest value and change handler, for the input callbacks bound once per drag / focus.
	local latest = React.useRef(props.value)
	local onChange = React.useRef(props.onChange)
	onChange.current = props.onChange
	-- One action name per slider, so two sliders never unbind each other's keys.
	local action = React.useMemo(function(): string
		return `ToonSlider{HttpService:GenerateGUID(false)}`
	end, {})

	-- Follow the authoritative value whenever the knob is not held.
	local followDeps: { unknown } = { props.value, dragging }
	React.useEffect(function()
		if not dragging then
			setShown(props.value)
			latest.current = props.value
		end
	end, followDeps)

	local function commit(value: number)
		if value ~= latest.current then
			latest.current = value
			setShown(value)
			onChange.current(value)
		end
	end

	local function fromX(x: number)
		local frame = track.frame
		if frame ~= nil then
			commit(ToonSliderViewModel.fromPointer(x, frame.AbsolutePosition.X, frame.AbsoluteSize.X, min, max, step))
		end
	end

	-- A drag follows the pointer anywhere on screen until the press is released.
	React.useEffect(function(): () -> ()
		if not dragging then
			return function() end
		end
		local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				fromX(input.Position.X)
			end
		end)
		local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
			if isPress(input) then
				setDragging(false)
			end
		end)
		return function()
			moved:Disconnect()
			ended:Disconnect()
		end
	end, { dragging })

	-- Keys and the d-pad step the value while the slider has focus.
	local focused = not disabled and (hovered or selected or dragging)
	local keyDeps: { unknown } = { focused, min, max, step }
	React.useEffect(function(): () -> ()
		if not focused then
			return function() end
		end
		ContextActionService:BindActionAtPriority(
			action,
			function(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
				if state == Enum.UserInputState.Begin then
					local direction = ToonSliderViewModel.direction(input.KeyCode)
					if direction ~= 0 then
						commit(ToonSliderViewModel.nudge(latest.current, direction, min, max, step))
					end
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			table.unpack(NUDGE_KEYS)
		)
		return function()
			ContextActionService:UnbindAction(action)
		end
	end, keyDeps)

	local fraction = ToonSliderViewModel.fraction(shown, min, max)
	local format = props.format
	local text = if format ~= nil then format(shown) else ToonSliderViewModel.percent(shown, min, max)
	-- The knob takes the kit's own states: hover lifts it, a held knob sinks onto its drop, focus lights the ring.
	local pose = useToonPose(
		ToonStyleViewModel.pose({
			hovered = hovered and not dragging,
			pressed = dragging,
			selected = focused,
			disabled = disabled,
			receded = false,
		}),
		if dragging then MOTION.pressSeconds else MOTION.hoverSeconds
	)

	return e("TextButton", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Selectable = not disabled,
		Active = not disabled,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		-- Gamepad selection stays on the slider sideways: the d-pad steps the value instead.
		ref = function(rbx: TextButton?)
			if rbx ~= nil then
				rbx.NextSelectionLeft = rbx
				rbx.NextSelectionRight = rbx
			end
		end,
		[React.Event.InputBegan] = function(_: TextButton, input: InputObject)
			if not disabled and isPress(input) then
				setDragging(true)
				fromX(input.Position.X)
			end
		end,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
		[React.Event.SelectionGained] = function()
			setSelected(true)
		end,
		[React.Event.SelectionLost] = function()
			setSelected(false)
		end,
	}, {
		-- The track (knob-radius insets, so the knob's centre reaches both ends) on its hard ink drop.
		rail = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, KNOB / 2, 0.5, 0),
			Size = UDim2.new(1, -KNOB - PILL - GAP, 0, TRACK),
			BackgroundTransparency = 1,
			ref = function(rbx: Frame?)
				track.frame = rbx
			end,
		}, {
			drop = e("Frame", {
				Position = UDim2.fromOffset(0, DEPTH.drop - 3),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = COLOR.ink,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, { corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
			bar = e(ToonBar, {
				kind = if disabled then "load" else props.kind or "load",
				fill = fraction,
				size = UDim2.fromScale(1, 1),
				zIndex = 2,
			}),
			-- The knob rides the track's centre line at the value.
			knob = e(ToonSurface, {
				hue = if disabled then "steel" else "cream",
				radius = KNOB / 2,
				small = true,
				pose = pose,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.new(fraction, 0, 0.5, -2),
				size = UDim2.fromOffset(KNOB, KNOB),
				zIndex = 5,
			}),
		}),
		value = e(ToonPill, {
			text = text,
			hue = "night",
			textSize = 20,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.fromScale(1, 0.5),
			size = UDim2.fromOffset(PILL, 36),
			zIndex = 3,
		}),
	})
end

return ToonSlider
