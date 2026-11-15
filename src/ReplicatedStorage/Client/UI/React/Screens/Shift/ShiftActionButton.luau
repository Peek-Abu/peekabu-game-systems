--!strict
--[=[
	ShiftActionButton: one round button of the phone's action arc (ShiftMobileButtons) in the V1 kit: a round plate on
	the depth stack, grape for the big VACUUM / BANK button and night for the small ones (the in-run HUD stays dark and
	restrained), mint while it is ready (BANK at the truck, CROUCH while crouched), coral while it warns (LEAVE once a
	hiding stay is cramped), steel and half-faded while it is unavailable (it then ignores input). A hold prompt's
	progress (`fill`) draws as a mint bar under the button. The label is stroked display type; a press sinks the plate onto its drop.
	`spot` places it from the screen's bottom-right corner (ShiftHudViewModel.arcFor). Holds go through `onHoldBegin` /
	`onHoldEnd`, taps through `onActivated`. Presentational (exempt; story in ShiftActionButton.story; the arc and the
	states are specced in ShiftHudViewModel).

	@class ShiftActionButton
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftHudViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHudViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local ToonBar = require(Toon.ToonBar)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPose = require(Toon.useToonPose)

local e = React.createElement

export type ShiftActionButtonProps = {
	label: string,
	spot: ShiftHudViewModel.ArcSpot,
	large: boolean,
	available: boolean,
	ready: boolean,
	warn: boolean?,
	-- 0-1: a hold in progress, drawn as a bar under the button; nil: none.
	fill: number?,
	onActivated: (() -> ())?,
	onHoldBegin: (() -> ())?,
	onHoldEnd: (() -> ())?,
}

-- An unavailable button draws at half opacity.
local DIM = 0.5

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function ShiftActionButton(props: ShiftActionButtonProps): React.ReactNode
	local pressed, setPressed = React.useState(false)
	local onHoldBegin = props.onHoldBegin
	local onHoldEnd = props.onHoldEnd
	local onActivated = props.onActivated
	local spot = props.spot
	local available = props.available
	local hue: UIToonConstants.Hue = if not available
		then "steel"
		elseif props.warn == true then "coral"
		elseif props.ready then "mint"
		elseif props.large then "grape"
		else "night"
	local pose = useToonPose(
		ToonStyleViewModel.pose({
			hovered = false,
			pressed = pressed and available,
			selected = false,
			disabled = not available,
			receded = false,
		}),
		if pressed then UIToonConstants.MOTION.pressSeconds else UIToonConstants.MOTION.hoverSeconds
	)
	local face: { [string]: React.ReactNode } = {
		label = e(ToonText, {
			text = props.label,
			textSize = if props.large then 24 else 16,
			position = UDim2.fromOffset(6, 0),
			size = UDim2.new(1, -12, 1, 0),
			align = "center",
			fit = true,
		}),
	}
	return e("TextButton", {
		Position = UDim2.new(1, spot.x, 1, spot.y),
		Size = UDim2.fromOffset(spot.size, spot.size),
		AutoButtonColor = false,
		Active = available,
		BackgroundTransparency = 1,
		Text = "",
		[React.Event.InputBegan] = function(_button: TextButton, input: InputObject)
			if not isPress(input) then
				return
			end
			setPressed(true)
			if onHoldBegin ~= nil then
				onHoldBegin()
			end
		end,
		[React.Event.InputEnded] = function(_button: TextButton, input: InputObject)
			if not isPress(input) then
				return
			end
			setPressed(false)
			if onHoldEnd ~= nil then
				onHoldEnd()
			end
		end,
		[React.Event.Activated] = function()
			if available and onActivated ~= nil then
				onActivated()
			end
		end,
		[React.Event.MouseLeave] = function()
			setPressed(false)
			if onHoldEnd ~= nil then
				onHoldEnd()
			end
		end,
	}, {
		-- A CanvasGroup only while faded (one per dimmed button, not per button); room for the hard drop below.
		group = e(if available then "Frame" else "CanvasGroup", {
			Size = UDim2.new(1, 0, 1, UIToonConstants.DEPTH.drop + 2),
			BackgroundTransparency = 1,
			GroupTransparency = if available then nil else DIM,
		}, {
			plate = e(ToonSurface, {
				hue = hue,
				radius = 999,
				pose = pose,
				gloss = props.ready or props.large,
				size = UDim2.new(1, 0, 1, -(UIToonConstants.DEPTH.drop + 2)),
				children = face,
			}),
		}),
		fill = if props.fill ~= nil
			then e(ToonBar, {
				kind = "xp",
				fill = props.fill,
				position = UDim2.new(0.1, 0, 1, UIToonConstants.DEPTH.drop + 4),
				size = UDim2.new(0.8, 0, 0, 10),
			})
			else nil,
	})
end

return ShiftActionButton
