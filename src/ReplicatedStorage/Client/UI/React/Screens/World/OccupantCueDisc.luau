--!strict
--[=[
	OccupantCueDisc: Harlow's cue (Figma World UI 2b, W7) at its 140x140 design size: a Ø120 disc with a 6 px ring and
	the glyph in Oswald 90, turned by the view's tilt, over a soft night shadow. Presentational; the colours and tilt are
	OccupantWorldViewModel.cue.

	@class OccupantCueDisc
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local OccupantWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantWorldViewModel)

local e = React.createElement

export type OccupantCueDiscProps = {
	view: OccupantWorldViewModel.CueView,
}

local DISC = 120

local function OccupantCueDisc(props: OccupantCueDiscProps): React.ReactNode
	local view = props.view
	return e("Frame", {
		Size = UDim2.fromOffset(140, 140),
		BackgroundTransparency = 1,
	}, {
		shadow = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 5),
			Size = UDim2.fromOffset(DISC + 12, DISC + 12),
			BackgroundColor3 = UIPaperConstants.COLOR.night,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		disc = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(DISC, DISC),
			Rotation = view.tilt,
			BackgroundColor3 = view.fill,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			ring = e("UIStroke", {
				Color = view.ring,
				Thickness = 6,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			glyph = e(PaperLabel, {
				text = view.glyph,
				role = "heading",
				size = 90,
				color = view.ink,
				align = "center",
				frame = UDim2.fromScale(1, 1),
				autoSize = false,
				wrapped = false,
			}),
		}),
	})
end

return OccupantCueDisc
