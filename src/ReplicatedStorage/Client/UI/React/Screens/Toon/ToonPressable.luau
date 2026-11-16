--!strict
--[=[
	ToonPressable: a big tappable card (a Shop offer, an Inventory item, a crew card on Pick a Crew) that moves like the
	kit's buttons (owner picks M1 + M4, 2026-11-16): it lifts and grows a touch under the mouse, finger or gamepad
	selection, squishes for a blink when pressed, and, given `deal`, pops in as its page opens, one card after another
	(only the first MOTION.dealCount; the rest are simply there). The card's own art is `children`, drawn inside a body
	frame that the pose moves and scales, so the card's layout is unchanged at rest. Reduced Motion: no tweens (the
	hooks snap). Presentational (exempt; the pose is specced in ToonStyleViewModel.pose, the deal in
	ToonMotionViewModel.deal / dealDelay).

	@class ToonPressable
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonMotionViewModel = require(Toon.ToonMotionViewModel)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)
local useToonPose = require(Toon.useToonPose)

local e = React.createElement

local MOTION = UIToonConstants.MOTION

-- A press sinks the card only this far (design px): the whole card moves, its drop with it, so the button's deeper
-- sink would read as the card jumping.
local PRESS_SINK = 2

export type ToonPressableProps = {
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	onActivated: () -> (),
	-- The card's place on its page (1-based) when it should be dealt in as the page opens.
	deal: number?,
	disabled: boolean?,
	zIndex: number?,
	layoutOrder: number?,
	children: { [string]: React.ReactNode }?,
}

local function isPress(input: InputObject?): boolean
	return input ~= nil
		and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1)
end

local function ToonPressable(props: ToonPressableProps): React.ReactNode
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local disabled = props.disabled == true
	local target = ToonStyleViewModel.pose({
		hovered = hovered,
		pressed = pressed,
		selected = false,
		disabled = disabled,
		receded = false,
	})
	local pose = useToonPose(target, if pressed then MOTION.pressSeconds else MOTION.hoverSeconds)
	local delay = if props.deal ~= nil then ToonMotionViewModel.dealDelay(props.deal) else nil
	local dealt = useToonPlay(if delay ~= nil then MOTION.dealSeconds else 0, delay or 0, nil)
	return e("TextButton", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = not disabled,
		Text = "",
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
		[React.Event.MouseEnter] = function(_button: TextButton)
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function(_button: TextButton)
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.SelectionGained] = function(_button: TextButton)
			setHovered(true)
		end,
		[React.Event.SelectionLost] = function(_button: TextButton)
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.InputBegan] = function(_button: TextButton, input: InputObject?)
			if not disabled and isPress(input) then
				setPressed(true)
			end
		end,
		[React.Event.InputEnded] = function(_button: TextButton, _input: InputObject?)
			setPressed(false)
		end,
		[React.Event.Activated] = function(_button: TextButton)
			if not disabled then
				props.onActivated()
			end
		end,
	}, {
		-- The deal scales the whole card; inside it the pose lifts and scales it (nested UIScales multiply).
		dealt = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			scale = e("UIScale", {
				Scale = dealt:map(function(t: number): number
					return if delay ~= nil then ToonMotionViewModel.deal(t) else 1
				end),
			}),
			body = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = pose:map(function(value: ToonStyleViewModel.Pose): UDim2
					return UDim2.new(0.5, 0, 0.5, -math.max(value.lift, -PRESS_SINK))
				end),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, {
				scale = e("UIScale", {
					Scale = pose:map(function(value: ToonStyleViewModel.Pose): number
						return value.scale
					end),
				}),
				card = if props.children ~= nil then e(React.Fragment, nil, props.children) else nil,
			}),
		}),
	})
end

return ToonPressable
