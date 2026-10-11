--!strict
--[=[
	ShiftClockOutSlip: the stapled, torn clock-out slip under the time card while the crew clocks out (Figma 1c
	"Clock-out countdown", 500x128 at top centre): the red "CLOCK-OUT SLIP — TRUCK 2" band, "LEAVING IN" over the red
	Roboto Mono countdown, and "Get in the truck bed. / Unbanked cargo stays." past a ruled divider. Presentational
	(desktop; phone is Task 10).

	@class ShiftClockOutSlip
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local PaperSheet = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperSheet)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

local e = React.createElement

export type ShiftClockOutSlipProps = {
	left: string,
	truck: number?,
	layout: UIPaperConstants.Layout,
}

local COLOR = UIPaperConstants.COLOR
local TEXT = UIPaperConstants.TEXT.desktop
-- Figma 1c: the slip's top edge (y 262); content positions are Figma's minus the 26 px band.
local TOP = 262
local HOLES = 5

local function ShiftClockOutSlip(props: ShiftClockOutSlipProps): React.ReactNode
	local truck = props.truck
	local children: { [string]: React.ReactNode } = {
		leaving = e(PaperLabel, {
			text = "LEAVING IN",
			role = "body",
			size = TEXT.label,
			position = UDim2.fromOffset(40, 14),
			frame = UDim2.fromOffset(160, 22),
			autoSize = false,
			wrapped = false,
		}),
		countdown = e(PaperLabel, {
			text = props.left,
			role = "timer",
			size = 52,
			color = COLOR.stamp,
			position = UDim2.fromOffset(38, 32),
			frame = UDim2.fromOffset(160, 66),
			autoSize = false,
			wrapped = false,
		}),
		divider = e("Frame", {
			Position = UDim2.fromOffset(206, 18),
			Size = UDim2.fromOffset(2, 70),
			BackgroundColor3 = COLOR.manilaDeep,
			BorderSizePixel = 0,
		}),
		instructions = e(PaperLabel, {
			text = "Get in the truck bed.\nUnbanked cargo stays.",
			role = "body",
			size = TEXT.label,
			position = UDim2.fromOffset(224, 22),
			frame = UDim2.fromOffset(262, 52),
			autoSize = false,
		}),
	}
	-- The binder's punch holes down the left edge.
	for index = 1, HOLES do
		children[`hole{index}`] = e("Frame", {
			Position = UDim2.fromOffset(16, 16 + (index - 1) * 14),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = COLOR.ink,
			BorderSizePixel = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	return e(PaperSheet, {
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, TOP),
		size = UDim2.fromOffset(500, 128),
		paper = COLOR.cream,
		band = if truck ~= nil then `CLOCK-OUT SLIP — TRUCK {truck}` else "CLOCK-OUT SLIP",
		fastener = "staple",
		torn = true,
		tilt = -1,
		padding = 0,
		children = children,
	})
end

return ShiftClockOutSlip
