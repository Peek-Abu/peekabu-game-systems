--!strict
--[=[
	PaperButton: the kit's button (Components 5:2): an Oswald Bold label on a flat fill. `primary` is manila with
	ink, `secondary` a 3 px outline (cream on the dark office, ink when `onPaper`), `danger` stamp red with cream,
	`go` exit green with night. `disabled` fades it to half and swallows activation. `mark` writes a note to the
	right of the button in Permanent Marker (the review's "your vote"; words, never a glyph). Presentational.

	@class PaperButton
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

export type Variant = "primary" | "secondary" | "danger" | "go"

export type PaperButtonProps = {
	text: string,
	variant: Variant,
	onActivated: () -> (),
	size: UDim2,
	textSize: number,
	onPaper: boolean?,
	mark: string?,
	disabled: boolean?,
	position: UDim2?,
	anchor: Vector2?,
	layoutOrder: number?,
}

type Look = "primary" | "secondary" | "secondaryOnPaper" | "danger" | "go"
-- `filled = false` is the outline look: no fill, a stroke in the text colour.
type Style = { fill: Color3, text: Color3, filled: boolean }

local COLOR = UIPaperConstants.COLOR
local STROKE = 3

local STYLE: { [Look]: Style } = table.freeze({
	primary = { fill = COLOR.manila, text = COLOR.ink, filled = true },
	secondary = { fill = COLOR.cream, text = COLOR.cream, filled = false },
	secondaryOnPaper = { fill = COLOR.ink, text = COLOR.ink, filled = false },
	danger = { fill = COLOR.stamp, text = COLOR.cream, filled = true },
	go = { fill = COLOR.exitGreen, text = COLOR.night, filled = true },
})

local function PaperButton(props: PaperButtonProps): React.ReactNode
	local disabled = props.disabled == true
	local onPaper = props.onPaper == true
	local look: Look = if props.variant == "secondary" and onPaper then "secondaryOnPaper" else props.variant
	local style = STYLE[look]
	local fade = if disabled then 0.5 else 0

	local children: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		label = e(PaperLabel, {
			text = props.text,
			role = "heading",
			size = props.textSize,
			color = style.text,
			align = "center",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			fit = true,
			transparency = fade,
		}),
	}
	if not style.filled then
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

	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = style.fill,
		BackgroundTransparency = if style.filled then fade else 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		[React.Event.Activated] = function()
			if not disabled then
				props.onActivated()
			end
		end,
	}, children)
end

return PaperButton
