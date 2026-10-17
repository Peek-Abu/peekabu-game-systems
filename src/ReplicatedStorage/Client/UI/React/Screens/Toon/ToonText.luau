--!strict
--[=[
	ToonText: the kit's type. `display` (the default) is Luckiest Guy with a thick round-jointed ink stroke, a
	gradient fill by meaning (gold = Gleam, mint = gain, coral = time and danger, grape = Gloom, white = labels) and a
	hard ink drop (a duplicate label offset down). `body` is Fredoka One, ink on light faces and white on dark ones,
	with no stroke. The text sits in a box (`size`, aligned by `align`); `fit` shrinks it to stay inside the box (its limits follow
	PaperScaleContext, the scale a surface is drawn at). Display text is placed optically: Luckiest Guy's caps fill the
	top of its line box and the drop hangs under them, so centred (or bottom-aligned) text is lowered until its caps and
	drop, together, sit centred in (or on the foot of) the box (ToonStyleViewModel.optical, at the size it is drawn).
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
	-- A number, or a binding (a fade that never re-renders).
	transparency: (number | React.Binding<number>)?,
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
	local transparency = props.transparency
	-- A UITextSizeConstraint counts real screen px and ignores the UIScale the text is drawn under, so the fit limits
	-- follow the scale the surface provides (PaperHudFrame and the scaled screens provide it; 1 elsewhere).
	local scale = React.useContext(PaperScaleContext.Context)
	local auto = props.automaticWidth == true
	-- TextScaled wraps words whenever two lines fit the box, so a fitted single line is drawn in a box only one
	-- line tall (centred on the caller's box by alignY): then shrinking to the width always wins.
	local oneLine = fit and props.wrapped ~= true
	local alignY: "top" | "center" | "bottom" = props.alignY or "center"
	local lineHeight = math.ceil(size * 1.3)
	local anchorY = if alignY == "top" then 0 elseif alignY == "bottom" then 1 else 0.5
	-- The size the display text is really drawn at (a fitted line may shrink below textSize): read off the label's
	-- TextBounds (one line's height is its size for Luckiest Guy) against its drawn height, so it holds under a UIScale.
	local drawn, setDrawn = React.useBinding(size)
	local measure = if display and oneLine
		then function(rbx: TextLabel)
			local height = rbx.AbsoluteSize.Y
			if height > 0 and rbx.TextBounds.Y > 0 then
				setDrawn(math.min(size, rbx.TextBounds.Y / height * lineHeight))
			end
		end
		else nil
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
		-- Display text is lowered so its caps (and its drop with it) sit optically centred in the box: Luckiest Guy's
		-- caps fill the top of its line box (ToonStyleViewModel.optical). Body text (Fredoka) is centred as drawn.
		local dropPx = if drop then ToonStyleViewModel.drop(size) else 0
		local function offsetY(value: number): number
			if not display then
				return dropPx
			end
			return dropPx + ToonStyleViewModel.optical(alignY, value, ToonStyleViewModel.drop(value))
		end
		-- A fitted display line keeps its ink stroke inside the box too (TextScaled fits the glyphs, not the stroke).
		local inset = if display and oneLine then stroke else 0
		local position: UDim2 | React.Binding<UDim2>
		if oneLine then
			position = drawn:map(function(value: number): UDim2
				return UDim2.new(0, inset, anchorY, offsetY(value))
			end)
		else
			position = UDim2.fromOffset(0, offsetY(size))
		end
		return e("TextLabel", {
			AnchorPoint = if oneLine then Vector2.new(0, anchorY) else nil,
			Position = position,
			Size = if auto
				then UDim2.fromScale(0, 1)
				elseif oneLine then UDim2.new(1, -2 * inset, 0, lineHeight)
				else UDim2.fromScale(1, 1),
			AutomaticSize = if auto then Enum.AutomaticSize.X else nil,
			BackgroundTransparency = 1,
			Text = props.text,
			RichText = props.richText == true,
			FontFace = if display then UIToonConstants.FONT.display else UIToonConstants.FONT.body,
			TextSize = size,
			TextScaled = fit,
			-- A fitted single line shrinks to the box width; wrapped text shrinks to its lines.
			TextWrapped = props.wrapped == true,
			TextColor3 = if drop then COLOR.ink elseif display then COLOR.white else props.color or COLOR.ink,
			TextTransparency = transparency,
			TextXAlignment = X_ALIGN[props.align or "left"],
			TextYAlignment = Y_ALIGN[alignY],
			ZIndex = if drop then 1 else 2,
			[React.Change.TextBounds] = if drop then nil else measure,
			[React.Change.AbsoluteSize] = if drop then nil else measure,
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
