--!strict
--[=[
	PaperLabel: text in one of the kit's type roles (UIPaperConstants.FONT). Presentational.

	Fills its parent's width and grows to its text height by default; `frame` fixes the size, `autoSize = false`
	stops the growth, and `fit` sizes it to the text on both axes (for chips, stamps and marks). `strike` crosses the
	text out with rich text; the text is escaped first (`&`, `<`, `>`) because callers pass player display names.
	`scaled` shrinks long text into the fixed `frame` (TextScaled with a UITextSizeConstraint from `minSize` to `size`,
	times the sign's scale from PaperScaleContext, because the constraint counts screen px); it never auto-sizes.

	@class PaperLabel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

export type Role = "body" | "heading" | "medium" | "number" | "timer" | "marker"

export type PaperLabelProps = {
	text: string,
	role: Role,
	size: number,
	color: Color3?,
	align: ("left" | "center" | "right")?,
	frame: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	transparency: number?,
	wrapped: boolean?,
	autoSize: boolean?,
	-- Size to the text on both axes (AutomaticSize XY); wins over `frame` and `autoSize`.
	fit: boolean?,
	strike: boolean?,
	-- Shrink long text into the fixed `frame` (TextScaled, between `minSize` and `size`); pair with autoSize = false.
	scaled: boolean?,
	-- The smallest scaled size in design px (floor(size * 0.6) by default).
	minSize: number?,
	layoutOrder: number?,
	zIndex: number?,
}

local ALIGN = table.freeze({
	left = Enum.TextXAlignment.Left,
	center = Enum.TextXAlignment.Center,
	right = Enum.TextXAlignment.Right,
})

-- Rich-text escapes for a struck-through (RichText) label.
local ESCAPES = table.freeze({ ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" })

local function PaperLabel(props: PaperLabelProps): React.ReactNode
	local strike = props.strike == true
	local signScale = React.useContext(PaperScaleContext.Context)
	local scaled = props.scaled == true
	local text = props.text
	if strike then
		local escaped = string.gsub(text, "[<>&]", ESCAPES)
		text = `<s>{escaped}</s>`
	end

	local fit = props.fit == true
	local size = if fit then UDim2.fromOffset(0, 0) else props.frame or UDim2.fromScale(1, 0)
	local autoSize = if fit
		then Enum.AutomaticSize.XY
		elseif scaled or props.autoSize == false then Enum.AutomaticSize.None
		else Enum.AutomaticSize.Y

	return e("TextLabel", {
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = size,
		AutomaticSize = autoSize,
		BackgroundTransparency = 1,
		FontFace = UIPaperConstants.FONT[props.role],
		TextSize = props.size,
		TextColor3 = props.color or UIPaperConstants.COLOR.ink,
		TextTransparency = props.transparency or 0,
		TextXAlignment = ALIGN[props.align or "left"],
		TextWrapped = not fit and props.wrapped ~= false,
		RichText = strike,
		TextScaled = scaled,
		Text = text,
	}, {
		limit = if scaled
			then e("UITextSizeConstraint", {
				MaxTextSize = signScale:map(function(scale: number): number
					return PaperScaleContext.limit(props.size, scale)
				end),
				MinTextSize = signScale:map(function(scale: number): number
					return PaperScaleContext.limit(props.minSize or math.floor(props.size * 0.6), scale)
				end),
			})
			else nil,
	})
end

return PaperLabel
