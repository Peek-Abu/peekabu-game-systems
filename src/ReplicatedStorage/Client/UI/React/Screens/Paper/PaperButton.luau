--!strict
--[=[
	PaperButton: the kit's button (Components 5:2): an Oswald Bold label on a flat fill. `primary` is manila with
	ink, `secondary` a 3 px outline (cream on the dark office, ink when `onPaper`), `danger` stamp red with cream,
	`go` exit green with night. `disabled` fades it to half and swallows activation. `mark` writes a note to the
	right of the button in Permanent Marker (the review's "your vote"; words, never a glyph). Presentational, plus its
	sound: the hover as the pointer enters, and on a press its tier (`sound`: click / confirm / back / cta; absent =
	its look's default, UISoundFormulas.buttonTier), or the error while disabled (UISoundSystem).

	@class PaperButton
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local UISoundFormulas = require(ReplicatedStorage.Client.Features.UI.Utils.UISoundFormulas)
local UISoundSystem = require(ReplicatedStorage.Client.Features.UI.Systems.UISoundSystem)

local VM = require(script.Parent.PaperButtonViewModel)

local e = React.createElement

export type Variant = "primary" | "secondary" | "danger" | "go" | "prop" | "surface"

export type PaperButtonProps = {
	text: string,
	variant: Variant,
	onActivated: () -> (),
	size: UDim2,
	textSize: number,
	onPaper: boolean?,
	mark: string?,
	icon: React.ReactNode?,
	content: React.ReactNode?,
	selected: boolean?,
	disabled: boolean?,
	position: UDim2?,
	anchor: Vector2?,
	layoutOrder: number?,
	-- The press's UI sound tier (absent = the look's default: UISoundFormulas.buttonTier).
	sound: UISoundFormulas.Tier?,
}

type Look = "primary" | "secondary" | "secondaryOnPaper" | "danger" | "go" | "prop" | "surface"
-- `filled = false` is the outline look: no fill, a stroke in the text colour.
type Style = { fill: Color3, text: Color3, filled: boolean }

local COLOR = UIPaperConstants.COLOR
local STROKE = 3

local STYLE: { [Look]: Style } = table.freeze({
	surface = { fill = COLOR.cream, text = COLOR.ink, filled = false },
	prop = { fill = COLOR.cream, text = COLOR.ink, filled = true },
	primary = { fill = COLOR.manila, text = COLOR.ink, filled = true },
	secondary = { fill = COLOR.cream, text = COLOR.cream, filled = false },
	secondaryOnPaper = { fill = COLOR.ink, text = COLOR.ink, filled = false },
	danger = { fill = COLOR.stamp, text = COLOR.cream, filled = true },
	go = { fill = COLOR.exitGreen, text = COLOR.night, filled = true },
})

local function PaperButton(props: PaperButtonProps): React.ReactNode
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local focused, setFocused = React.useState(false)
	local reduced, setReduced = React.useState(GuiService.ReducedMotionEnabled)
	local pose, setPose = React.useBinding(VM.pose(false, false, false, false, false))
	local disabled = props.disabled == true
	React.useEffect(function(): () -> ()
		local connection = GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			setReduced(GuiService.ReducedMotionEnabled)
		end)
		local focusLost = UserInputService.WindowFocusReleased:Connect(function()
			setPressed(false)
		end)
		setReduced(GuiService.ReducedMotionEnabled)
		return function()
			focusLost:Disconnect()
			connection:Disconnect()
		end
	end, {})
	React.useEffect(function(): () -> ()
		local target = VM.pose(hovered, pressed, focused, disabled, reduced)
		local initial = pose:getValue()
		local connection: RBXScriptConnection? = nil
		if reduced or disabled then
			setPose(target)
		elseif initial.scale ~= target.scale or initial.tilt ~= target.tilt then
			local elapsed = 0
			local duration = if pressed then 0.09 else 0.16
			connection = RunService.RenderStepped:Connect(function(dt: number)
				elapsed += dt
				local progress = math.clamp(elapsed / duration, 0, 1)
				local eased = TweenService:GetValue(progress, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
				setPose({
					scale = initial.scale + (target.scale - initial.scale) * eased,
					tilt = initial.tilt + (target.tilt - initial.tilt) * eased,
				})
				if progress == 1 and connection ~= nil then
					connection:Disconnect()
				end
			end)
		end
		return function()
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end, { hovered, pressed, focused, disabled, reduced })
	React.useEffect(function()
		if disabled then
			setPressed(false)
		end
	end, { disabled })
	local onPaper = props.onPaper == true
	local look: Look = if props.variant == "secondary" and onPaper then "secondaryOnPaper" else props.variant
	local style = STYLE[look]
	local fade = if disabled then 0.5 else 0
	local treatment = VM.ink(hovered, pressed, focused, disabled)

	local children: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		label = e(PaperLabel, {
			text = props.text,
			role = "heading",
			size = props.textSize,
			color = style.text,
			align = "center",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, if props.variant == "prop" then 0.84 else 0.5),
			fit = true,
			transparency = fade,
		}),
	}
	if props.variant == "prop" then
		children.art = e(
			"Frame",
			{ Position = UDim2.fromScale(0.13, 0.12), Size = UDim2.fromScale(0.74, 0.57), BackgroundTransparency = 1 },
			{ icon = props.icon }
		)
		children.strip = e("Frame", {
			Size = UDim2.new(1, 0, 0, 5),
			BackgroundColor3 = if not disabled and (hovered or focused or pressed)
				then COLOR.manila
				else COLOR.companyTeal,
			BorderSizePixel = 0,
		})
		children.selection = e("UIStroke", {
			Color = COLOR.companyTeal,
			Thickness = if props.selected then 3 else 1,
			Transparency = if props.selected then 0 else 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end
	if not style.filled and props.variant ~= "surface" then
		children.stroke = e("UIStroke", {
			Color = style.text,
			Thickness = STROKE,
			Transparency = fade,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
	end
	if props.mark ~= nil then
		children.mark = e(PaperLabel, {
			text = props.mark,
			role = "marker",
			size = props.textSize,
			color = if onPaper then COLOR.ink else COLOR.cream,
			anchor = Vector2.new(0, 0.5),
			position = UDim2.new(1, 12, 0.5, 0),
			fit = true,
		})
	end

	if props.content ~= nil then
		children.label = nil
		children.content = props.content
	end
	children.scale = e("UIScale", {
		Scale = pose:map(function(value: VM.Pose): number
			return value.scale
		end),
	})
	local face = e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Rotation = pose:map(function(value: VM.Pose): number
			return value.tilt
		end),
		BackgroundColor3 = style.fill:Lerp(if style.filled then COLOR.ink else COLOR.manila, treatment),
		BackgroundTransparency = if props.variant == "surface" then 1 elseif style.filled then fade else 1 - treatment,
		BorderSizePixel = 0,
	}, children)
	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		Selectable = not disabled,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		[React.Event.MouseEnter] = function(_button: TextButton)
			setHovered(true)
			if UISoundFormulas.hovers(props.variant, disabled) then
				UISoundSystem.play("hover")
			end
		end,
		[React.Event.MouseLeave] = function(_button: TextButton)
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.SelectionGained] = function(_button: TextButton)
			setFocused(true)
		end,
		[React.Event.SelectionLost] = function(_button: TextButton)
			setFocused(false)
			setPressed(false)
		end,
		[React.Event.InputBegan] = function(_button: TextButton, input: InputObject?)
			if
				not disabled
				and input ~= nil
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
					or input.KeyCode == Enum.KeyCode.ButtonA
					or input.KeyCode == Enum.KeyCode.Return
				)
			then
				setPressed(true)
			end
		end,
		[React.Event.InputEnded] = function(_button: TextButton, _input: InputObject?)
			setPressed(false)
		end,
		[React.Event.Activated] = function(_button: TextButton)
			UISoundSystem.play(
				UISoundFormulas.pressTier(UISoundFormulas.buttonTier(props.variant, props.sound), disabled)
			)
			if not disabled then
				props.onActivated()
			end
		end,
	}, { PaperButtonFace = face })
end

return PaperButton
