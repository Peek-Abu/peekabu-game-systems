--!strict
--[=[
	OccupantMemo: Harlow's speech (Figma World UI 2b, W8) at its 520x166 design size: a 520x140 cream memo (textured once
	uploaded) under a 30 px stamp-red letterhead "MEMO — FROM THE DESK OF THE MANAGER" (Oswald 18, cream), the line in
	Special Elite (30 ink, or 38 red when shouted, shrinking to fit two lines), typed out letter by letter
	(useTypedGraphemes at OccupantConstants.TYPE_RATE), and a 24 px tail at x 90 pointing down at his head.
	Presentational; the words and the shout are OccupantWorldViewModel.memo.

	@class OccupantMemo
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local PaperScaleContext = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperScaleContext)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperTexture = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperTexture)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local OccupantWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.OccupantWorldViewModel)
local useTypedGraphemes = require(ReplicatedStorage.Client.UI.React.Screens.World.useTypedGraphemes)

local e = React.createElement

export type OccupantMemoProps = {
	view: OccupantWorldViewModel.MemoView,
}

local COLOR = UIPaperConstants.COLOR
local PAPER = Vector2.new(520, 140)
local BAND = 30
local TAIL = 24
local TAIL_X = 90

local function OccupantMemo(props: OccupantMemoProps): React.ReactNode
	local view = props.view
	local signScale = React.useContext(PaperScaleContext.Context)
	local shown = useTypedGraphemes(view.text, OccupantConstants.TYPE_RATE)
	return e("Frame", {
		Size = UDim2.fromOffset(PAPER.X, OccupantConstants.MEMO_PX.Y),
		BackgroundTransparency = 1,
	}, {
		shadow = e("Frame", {
			Position = UDim2.fromOffset(4, 6),
			Size = UDim2.fromOffset(PAPER.X, PAPER.Y),
			BackgroundColor3 = COLOR.night,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 0,
		}),
		-- A cream square turned 45° under the paper's bottom edge: its lower half is the tail.
		tail = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(TAIL_X, PAPER.Y),
			Size = UDim2.fromOffset(TAIL, TAIL),
			Rotation = 45,
			BackgroundColor3 = COLOR.cream,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, { texture = e(PaperTexture, { paper = COLOR.cream }) }),
		paper = e("Frame", {
			Size = UDim2.fromOffset(PAPER.X, PAPER.Y),
			BackgroundColor3 = COLOR.cream,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			texture = e(PaperTexture, { paper = COLOR.cream }),
			band = e("Frame", {
				Size = UDim2.new(1, 0, 0, BAND),
				BackgroundColor3 = COLOR.stamp,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				label = e(PaperLabel, {
					text = view.band,
					role = "heading",
					size = 18,
					color = COLOR.cream,
					position = UDim2.fromOffset(14, 0),
					frame = UDim2.new(1, -28, 1, 0),
					autoSize = false,
					wrapped = false,
				}),
			}),
			line = e("TextLabel", {
				Position = UDim2.fromOffset(18, BAND + 10),
				Size = UDim2.new(1, -36, 0, PAPER.Y - BAND - 18),
				BackgroundTransparency = 1,
				FontFace = UIPaperConstants.FONT.body,
				TextScaled = true,
				TextWrapped = true,
				TextColor3 = UIPaperConstants.inkColor(view.ink),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				RichText = false,
				Text = view.text,
				MaxVisibleGraphemes = shown,
				ZIndex = 2,
			}, {
				limit = e("UITextSizeConstraint", {
					MaxTextSize = signScale:map(function(scale: number): number
						return PaperScaleContext.limit(view.size, scale)
					end),
					MinTextSize = signScale:map(function(scale: number): number
						return PaperScaleContext.limit(12, scale)
					end),
				}),
			}),
		}),
	})
end

return OccupantMemo
