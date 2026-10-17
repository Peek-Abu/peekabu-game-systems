--!strict
--[=[
	ToonButton: the kit's button on the full depth stack. Every state is a tween of the same instances
	(ToonStyleViewModel.pose through useToonPose): hover lifts and grows it, press sinks it onto its drop, selected lifts
	it inside V2's lilac ring and glow, `receded` shrinks and dims an unselected sibling, disabled greys it and
	answers a press with the error sound. Layouts: `inline` (a render left of the label: DEPART, 450), `tile` (a big
	render breaking the top edge over a label at the foot: the hub's JOBS / LOCKER tiles), `icon` (a render alone).
	`badge` sticks a coral tag over the top-right corner (NEW). The hit area never moves. Sound like PaperButton: the
	hover as the pointer enters, the press's tier (`sound`, else the variant's default), the error while disabled.
	Presentational (exempt; story in ToonButton.story; states specced in ToonStyleViewModel).

	@class ToonButton
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UISoundFormulas = require(ReplicatedStorage.Client.Features.UI.Utils.UISoundFormulas)
local UISoundSystem = require(ReplicatedStorage.Client.Features.UI.Systems.UISoundSystem)
local ToonIcon = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonIcon)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local ToonSurface = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSurface)
local ToonText = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonText)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local useToonPose = require(ReplicatedStorage.Client.UI.React.Screens.Toon.useToonPose)

local e = React.createElement

local MOTION = UIToonConstants.MOTION

export type Layout = "inline" | "tile" | "icon"

export type ToonButtonProps = {
	variant: ToonStyleViewModel.Variant,
	size: UDim2,
	onActivated: () -> (),
	text: string?,
	textSize: number?,
	icon: UIAssets.ToonIcon?,
	layout: Layout?,
	position: UDim2?,
	anchor: Vector2?,
	radius: number?,
	disabled: boolean?,
	selected: boolean?,
	receded: boolean?,
	badge: string?,
	-- Smaller chrome (pills and tags that are buttons).
	small: boolean?,
	-- Drawn on the face instead of the text and icon (a CTA's own content).
	content: { [string]: React.ReactNode }?,
	sound: UISoundFormulas.Tier?,
	layoutOrder: number?,
	zIndex: number?,
}

local function pressInput(input: InputObject?): boolean
	return input ~= nil
		and (
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
			or input.KeyCode == Enum.KeyCode.Return
		)
end

local function face(props: ToonButtonProps, disabled: boolean): { [string]: React.ReactNode }
	if props.content ~= nil then
		return props.content
	end
	local layout = props.layout or "inline"
	local textSize = props.textSize or 28
	local children: { [string]: React.ReactNode } = {}
	if layout == "tile" then
		-- The render breaks the top edge; the label sits at the foot.
		if props.icon ~= nil then
			children.icon = e(ToonIcon, {
				icon = props.icon,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.3),
				size = UDim2.fromScale(0.92, 0.82),
				greyed = disabled,
				zIndex = 2,
			})
		end
		if props.text ~= nil then
			children.label = e(ToonText, {
				text = props.text,
				textSize = textSize,
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -4),
				size = UDim2.new(1, -8, 0, textSize + 6),
				align = "center",
				fit = true,
				zIndex = 3,
			})
		end
	elseif layout == "icon" then
		if props.icon ~= nil then
			children.icon = e(ToonIcon, {
				icon = props.icon,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.45),
				size = UDim2.fromScale(1.05, 1.05),
				greyed = disabled,
			})
		end
	else
		local hasIcon = props.icon ~= nil
		if hasIcon then
			children.icon = e(ToonIcon, {
				icon = props.icon,
				anchor = Vector2.new(0, 0.5),
				position = UDim2.new(0, 6, 0.5, -2),
				size = UDim2.new(0, textSize * 1.9, 1.1, 0),
				drop = 3,
				greyed = disabled,
				zIndex = 2,
			})
		end
		if props.text ~= nil then
			local inset = if hasIcon then textSize * 1.9 + 8 else 12
			children.label = e(ToonText, {
				text = props.text,
				textSize = textSize,
				anchor = Vector2.new(0, 0.5),
				position = UDim2.new(0, inset, 0.5, -2),
				size = UDim2.new(1, -inset - 12, 1, -6),
				align = "center",
				fit = true,
				zIndex = 3,
			})
		end
	end
	return children
end

local function ToonButton(props: ToonButtonProps): React.ReactNode
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local disabled = props.disabled == true
	React.useEffect(function(): () -> ()
		local focusLost = UserInputService.WindowFocusReleased:Connect(function()
			setPressed(false)
		end)
		return function()
			focusLost:Disconnect()
		end
	end, {})
	React.useEffect(function()
		if disabled then
			setPressed(false)
		end
	end, { disabled })
	local target = ToonStyleViewModel.pose({
		hovered = hovered,
		pressed = pressed,
		selected = props.selected == true,
		disabled = disabled,
		receded = props.receded == true,
	})
	local pose = useToonPose(target, if pressed then MOTION.pressSeconds else MOTION.hoverSeconds)
	local hue: UIToonConstants.Hue = ToonStyleViewModel.hue(props.variant, disabled)

	local overlay: { [string]: React.ReactNode } = {}
	if props.badge ~= nil then
		local tag: { [string]: React.ReactNode } = {}
		tag.label = e(ToonText, {
			text = props.badge,
			textSize = 18,
			size = UDim2.fromScale(1, 1),
			align = "center",
		})
		overlay.badge = e(ToonSurface, {
			hue = "coral",
			small = true,
			radius = 10,
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(1, -10, 0, 4),
			size = UDim2.fromOffset(math.max(56, #props.badge * 14 + 20), 30),
			zIndex = 5,
			children = tag,
		})
	end

	return e("TextButton", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = not disabled,
		Text = "",
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
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
			setHovered(true)
		end,
		[React.Event.SelectionLost] = function(_button: TextButton)
			setHovered(false)
			setPressed(false)
		end,
		[React.Event.InputBegan] = function(_button: TextButton, input: InputObject?)
			if not disabled and pressInput(input) then
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
	}, {
		surface = e(ToonSurface, {
			hue = hue,
			size = UDim2.fromScale(1, 1),
			radius = props.radius,
			pose = pose,
			small = props.small,
			pattern = if hue == "cream" then "sparkle" else nil,
			children = face(props, disabled),
			overlay = overlay,
		}),
	})
end

return ToonButton
