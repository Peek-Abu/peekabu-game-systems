--!strict
--[=[
	CargoLoadFloater: a load floater (Figma World UI 2b, W6) at its 340x130 design size. Clearance: "+15" in Oswald 80
	fluorGlow with a 4 px night outline over "CLEARED" (Oswald 26). Bonus: a 300x96 monitorDeep stamp with a 5 px
	monitor ring, "+40 BONUS" in Oswald 56 monitor blue, turned 5° clockwise (the frame's stamp leans with its right
	edge down). `fade` (0 → 1) is every part's transparency, driven by CargoFeedbackSystem's tween, so fading never
	re-renders. Presentational; the words are CargoWorldViewModel.floater.

	@class CargoLoadFloater
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)

local e = React.createElement

export type CargoLoadFloaterProps = {
	view: CargoWorldViewModel.FloaterView,
	fade: React.Binding<number>,
}

local COLOR = UIPaperConstants.COLOR
local FONT = UIPaperConstants.FONT

-- Oswald text in fluorGlow with a night outline (the stroke follows the glyphs: Contextual).
local function outlined(
	text: string,
	size: number,
	outline: number,
	y: number,
	height: number,
	fade: React.Binding<number>
): React.ReactNode
	return e("TextLabel", {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		FontFace = FONT.number,
		TextSize = size,
		TextColor3 = COLOR.fluorGlow,
		TextTransparency = fade,
		TextXAlignment = Enum.TextXAlignment.Center,
		RichText = false,
		Text = text,
	}, {
		outline = e("UIStroke", {
			Color = COLOR.night,
			Thickness = outline,
			Transparency = fade,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),
	})
end

local function CargoLoadFloater(props: CargoLoadFloaterProps): React.ReactNode
	local view = props.view
	local fade = props.fade
	if view.bonus then
		return e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(300, 96),
			Rotation = 5,
			BackgroundColor3 = COLOR.monitorDeep,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			ring = e("UIStroke", {
				Color = COLOR.monitor,
				Thickness = 5,
				Transparency = fade,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			label = e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = FONT.heading,
				TextSize = 56,
				TextColor3 = COLOR.monitor,
				TextTransparency = fade,
				TextXAlignment = Enum.TextXAlignment.Center,
				RichText = false,
				Text = view.text,
			}),
		})
	end
	local children: { [string]: React.ReactNode } = {
		amount = outlined(view.text, 80, 4, 0, 92, fade),
	}
	local caption = view.caption
	if caption ~= nil then
		children.caption = outlined(caption, 26, 2, 92, 34, fade)
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, children)
end

return CargoLoadFloater
