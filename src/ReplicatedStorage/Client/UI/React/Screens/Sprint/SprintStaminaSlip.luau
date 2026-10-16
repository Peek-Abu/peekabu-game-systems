--!strict
--[=[
	SprintStaminaSlip: the stamina bar as paperwork (docs/superpowers/specs/2026-10-15-cleanup-crew-chase-kit-design.md
	§3): a small cream slip headed "WIND", with a row of ten punch-card boxes inked in teal as far as the bar
	reaches (the last box partly), stamp red under the restart fraction. It sits tucked against the equipment cards
	(ShiftCompactHudPanel places it) and shows only while the bar is not full. Presentational: it draws the BarView it
	is given (SprintViewModel.bar).

	@class SprintStaminaSlip
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local SprintViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Sprint.SprintViewModel)

local e = React.createElement

export type SprintStaminaSlipProps = {
	view: SprintViewModel.BarView,
	size: Vector2,
	position: UDim2,
	anchor: Vector2,
}

local COLOR = UIPaperConstants.COLOR
local BOXES = 10
local PADDING = 6
local LABEL_WIDTH = 38
local GAP = 3

local function SprintStaminaSlip(props: SprintStaminaSlipProps): React.ReactNode
	local view = props.view
	local inner = props.size - Vector2.new(PADDING * 2, PADDING * 2)
	local rowWidth = inner.X - LABEL_WIDTH
	local box = (rowWidth - GAP * (BOXES - 1)) / BOXES
	local ink = if view.low then COLOR.stamp else COLOR.companyTeal
	local children: { [string]: React.ReactNode } = {
		label = e(PaperLabel, {
			text = "WIND",
			role = "heading",
			size = 11,
			color = if view.low then COLOR.stamp else COLOR.ink,
			position = UDim2.fromOffset(0, 0),
			frame = UDim2.fromOffset(LABEL_WIDTH, inner.Y),
			autoSize = false,
			wrapped = false,
		}),
	}
	for index = 1, BOXES do
		local filled = math.clamp(view.fill * BOXES - (index - 1), 0, 1)
		children[`box{index}`] = e("Frame", {
			Position = UDim2.fromOffset(LABEL_WIDTH + (index - 1) * (box + GAP), 1),
			Size = UDim2.fromOffset(box, inner.Y - 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			outline = e("UIStroke", { Color = COLOR.ink, Thickness = 1, Transparency = 0.45 }),
			ink = if filled > 0
				then e("Frame", {
					Size = UDim2.fromScale(filled, 1),
					BackgroundColor3 = ink,
					BackgroundTransparency = 0.1,
					BorderSizePixel = 0,
				})
				else nil,
		})
	end
	return e(PaperSheet, {
		size = UDim2.fromOffset(props.size.X, props.size.Y),
		position = props.position,
		anchor = props.anchor,
		paper = COLOR.cream,
		tilt = -1,
		padding = PADDING,
		children = children,
	})
end

return SprintStaminaSlip
