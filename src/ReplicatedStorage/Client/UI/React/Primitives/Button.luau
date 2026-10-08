--!strict
--[=[
	Button: the shared button primitive. Deliberately broad — one component covers ordinary buttons AND
	tab-pills (via `selected`) so screens never hand-roll either. Presentational only: it styles itself
	from Tokens by variant/state and forwards activation; it holds no business logic (nothing to spec).

	Variants: `primary` (accent fill), `secondary` (raised surface, the default), `ghost` (transparent
	until hover). `selected` overrides the variant to the active/accent look — that's the tab case.
	`disabled` mutes it and swallows activation. Width auto-fits the text unless `width` is given.

	@class Button
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Tokens = require(ReplicatedStorage.Client.UI.React.Tokens)

local e = React.createElement

export type ButtonProps = {
	text: string,
	onActivated: () -> (),
	variant: ("primary" | "secondary" | "ghost")?,
	selected: boolean?, -- draws the active/accent look; use for tab-pills
	disabled: boolean?,
	width: number?, -- nil = auto-fit to the text
	layoutOrder: number?,
}

type Style = { bg: Color3, bgTransparency: number, fg: Color3 }

-- Resolve the fill + text colour from variant and state. Order matters: disabled and selected win
-- over the base variant.
local function resolveStyle(variant: string?, selected: boolean, disabled: boolean, hovered: boolean): Style
	if disabled then
		return { bg = Tokens.color.surface, bgTransparency = 0.2, fg = Tokens.color.textDisabled }
	end
	if selected or variant == "primary" then
		return {
			bg = if hovered then Tokens.color.accentHover else Tokens.color.accent,
			bgTransparency = 0,
			fg = Tokens.color.onAccent,
		}
	end
	if variant == "ghost" then
		return {
			bg = Tokens.color.surfaceRaised,
			bgTransparency = if hovered then 0.4 else 1,
			fg = Tokens.color.text,
		}
	end
	-- secondary (default)
	return {
		bg = if hovered then Tokens.color.surfaceOverlay else Tokens.color.surfaceRaised,
		bgTransparency = 0,
		fg = Tokens.color.text,
	}
end

--[=[
	@param props ButtonProps
	@return React.ReactNode
]=]
local function Button(props: ButtonProps): React.ReactNode
	local hovered, setHovered = React.useState(false)
	local disabled = props.disabled == true
	local style = resolveStyle(props.variant, props.selected == true, disabled, hovered and not disabled)

	-- Fixed width if asked, otherwise size to the text (both axes); height always follows the text.
	local fixedWidth = props.width
	local size: UDim2
	local autoSize: Enum.AutomaticSize
	if fixedWidth ~= nil then
		size = UDim2.fromOffset(fixedWidth, 0)
		autoSize = Enum.AutomaticSize.Y
	else
		size = UDim2.fromOffset(0, 0)
		autoSize = Enum.AutomaticSize.XY
	end

	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = size,
		AutomaticSize = autoSize,
		BackgroundColor3 = style.bg,
		BackgroundTransparency = style.bgTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false, -- hover/press styling is token-driven here, not the engine default
		Font = Tokens.font.medium,
		TextSize = Tokens.textSize.sm,
		TextColor3 = style.fg,
		Text = props.text,
		[React.Event.Activated] = function()
			if not disabled then
				props.onActivated()
			end
		end,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0, Tokens.radius.md) }),
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, Tokens.space.md),
			PaddingRight = UDim.new(0, Tokens.space.md),
			PaddingTop = UDim.new(0, Tokens.space.sm),
			PaddingBottom = UDim.new(0, Tokens.space.sm),
		}),
	})
end

return Button
