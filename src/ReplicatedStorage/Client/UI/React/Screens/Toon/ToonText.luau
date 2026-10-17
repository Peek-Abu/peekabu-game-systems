--!strict
--[=[
	ToonText: the kit's type. `display` (the default) is Luckiest Guy with a thick round-jointed ink stroke, a
	gradient fill by meaning (gold = Gleam, mint = gain, coral = time and danger, grape = Gloom, white = labels) and a
	hard ink drop (a duplicate label offset down). `body` is Fredoka One, ink on light faces and white on dark ones,
	with no stroke. The text sits in a box (`size`, aligned by `align`); `fit` shrinks it to stay inside the box (its limits follow
	PaperScaleContext, the scale a surface is drawn at).
	Presentational (exempt; story in ToonText.story; stroke and drop sizes specced in ToonStyleViewModel).

	@class ToonText
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type ToonTextProps = {
	text: string,
	textSize: number,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	-- "display" (default) or "body".
	font: ("display" | "body")?,
	-- The display fill (default white).
	meaning: UIToonConstants.Meaning?,
	-- Body text colour (default ink); display text ignores it.
	color: Color3?,
	align: ("left" | "center" | "right")?,
	alignY: ("top" | "center" | "bottom")?,
	-- Shrinks the text to fit the box (never above textSize).
	fit: boolean?,
	wrapped: boolean?,
	rotation: number?,
	transparency: number?,
	zIndex: number?,
	layoutOrder: number?,
	-- The box grows to the text's width (`size`'s X offset is then the least width).
	automaticWidth: boolean?,
	richText: boolean?,
}

local X_ALIGN = {
	left = Enum.TextXAlignment.Left,
	center = Enum.TextXAlignment.Center,
	right = Enum.TextXAlignment.Right,
}
local Y_ALIGN = {
	top = Enum.TextYAlignment.Top,
	center = Enum.TextYAlignment.Center,
	bottom = Enum.TextYAlignment.Bottom,
}

local function gradientOf(meaning: UIToonConstants.Meaning): ColorSequence
	local stops = UIToonConstants.NUMBER[meaning]
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, stops[1]),
		ColorSequenceKeypoint.new(0.35, stops[2]),
		ColorSequenceKeypoint.new(0.7, stops[3]),
		ColorSequenceKeypoint.new(1, stops[4]),
	})
end

local function ToonText(props: ToonTextProps): React.ReactNode
	local display = props.font ~= "body"
	local size = props.textSize
	local fit = props.fit == true
	local transparency = props.transparency or 0
	-- A UITextSizeConstraint counts real screen px and ignores the UIScale the text is drawn under, so the fit limits
	-- follow the scale the surface provides (PaperHudFrame and the scaled screens provide it; 1 elsewhere).
	local scale = React.useContext(PaperScaleContext.Context)
	local function label(drop: boolean): React.ReactNode
		local stroke = ToonStyleViewModel.stroke(size)
		local children: { [string]: React.ReactNode } = {}
		if display then
			children.stroke = e("UIStroke", {
				Color = COLOR.ink,
				Thickness = stroke,
				LineJoinMode = Enum.LineJoinMode.Round,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				Transparency = transparency,
			})
			if not drop then
				children.gradient = e("UIGradient", { Rotation = 90, Color = gradientOf(props.meaning or "white") })
			end
		end
		if fit then
			children.limit = e("UITextSizeConstraint", {
				MaxTextSize = scale:map(function(value: number): number
					return PaperScaleContext.limit(size, value)
				end),
				MinTextSize = scale:map(function(value: number): number
					return PaperScaleContext.limit(math.max(6, size * 0.4), value)
				end),
			})
		end
		local offset = if drop then ToonStyleViewModel.drop(size) else 0
		local auto = props.automaticWidth == true
		return e("TextLabel", {
			Position = UDim2.fromOffset(0, offset),
			Size = if auto then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 1),
			AutomaticSize = if auto then Enum.AutomaticSize.X else nil,
			BackgroundTransparency = 1,
			Text = props.text,
			RichText = props.richText == true,
			FontFace = if display then UIToonConstants.FONT.display else UIToonConstants.FONT.body,
			TextSize = size,
			TextScaled = fit,
			TextWrapped = props.wrapped == true or fit,
			TextColor3 = if drop then COLOR.ink elseif display then COLOR.white else props.color or COLOR.ink,
			TextTransparency = transparency,
			TextXAlignment = X_ALIGN[props.align or "left"],
			TextYAlignment = Y_ALIGN[props.alignY or "center"],
			ZIndex = if drop then 1 else 2,
		}, children)
	end
	return e("Frame", {
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		AutomaticSize = if props.automaticWidth then Enum.AutomaticSize.X else nil,
		Rotation = props.rotation,
		BackgroundTransparency = 1,
		ZIndex = props.zIndex,
		LayoutOrder = props.layoutOrder,
	}, {
		drop = if display then label(true) else nil,
		text = label(false),
	})
end

return ToonText
