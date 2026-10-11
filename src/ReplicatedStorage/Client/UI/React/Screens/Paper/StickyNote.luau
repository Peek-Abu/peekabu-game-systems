--!strict
--[=[
	StickyNote: a yellow sticky with a strip of tape across the top centre and Permanent Marker text. With `slide` it
	slides in from the right once on mount (UIPaperConstants.MOTION).

	The note is drawn on an INNER frame and the slide moves that frame, so the outer frame keeps its layout slot:
	the slide works under a UIListLayout (which ignores an element's own Position). The tilt is on the inner frame
	too, so a list of notes keeps its slots upright. Presentational.

	@class StickyNote
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperMotion = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperMotion)

local e = React.createElement

export type StickyNoteProps = {
	text: string,
	width: number,
	size: number,
	tilt: number?,
	slide: boolean?,
	position: UDim2?,
	anchor: Vector2?,
	layoutOrder: number?,
	-- The tape strip's size (110x26 by default).
	tape: Vector2?,
}

local COLOR = UIPaperConstants.COLOR
local MOTION = UIPaperConstants.MOTION
local DEFAULT_TAPE = Vector2.new(110, 26)

local function StickyNote(props: StickyNoteProps): React.ReactNode
	-- Called unconditionally (hook order); the slide reads it, a still note stays at 0.
	local alpha = usePaperMotion(MOTION.slideSeconds)
	local tape = props.tape or DEFAULT_TAPE
	local slideFrom = if props.slide == true then MOTION.slideFrom else 0
	local offset = alpha:map(function(value: number): UDim2
		return UDim2.fromOffset(slideFrom * (1 - value), 0)
	end)

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = UDim2.fromOffset(props.width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		note = e("Frame", {
			Position = offset,
			Size = UDim2.fromOffset(props.width, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Rotation = props.tilt or 0,
			BackgroundColor3 = COLOR.sticky,
			BorderSizePixel = 0,
		}, {
			texture = e(PaperTexture, { paper = COLOR.sticky }),
			-- Anchored at the top centre so a resized note keeps it centred (Figma CENTER constraint).
			tape = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromOffset(tape.X, tape.Y),
				BackgroundColor3 = COLOR.cream,
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				ZIndex = 3,
			}),
			body = e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, {
				padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 24),
					PaddingRight = UDim.new(0, 24),
					PaddingTop = UDim.new(0, 18),
					PaddingBottom = UDim.new(0, 18),
				}),
				label = e(PaperLabel, {
					text = props.text,
					role = "marker",
					size = props.size,
					color = COLOR.ink,
				}),
			}),
		}),
	})
end

return StickyNote
