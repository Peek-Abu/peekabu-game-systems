--!strict
--[=[
	PaperStamp: a rubber stamp ("QUOTA MET"), an outlined Oswald Bold word in stamp red at a slight tilt. With `pop`
	it drops in from 140% once on mount (UIPaperConstants.MOTION); remount it (change its key) to stamp again.
	Presentational.

	@class PaperStamp
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PaperLabel = require(ReplicatedStorage.Client.UI.React.Screens.Paper.PaperLabel)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local usePaperMotion = require(ReplicatedStorage.Client.UI.React.Screens.Paper.usePaperMotion)

local e = React.createElement

export type PaperStampProps = {
	text: string,
	size: number,
	color: Color3?,
	tilt: number?,
	pop: boolean?,
	position: UDim2?,
	anchor: Vector2?,
	layoutOrder: number?,
}

local MOTION = UIPaperConstants.MOTION

local function PaperStamp(props: PaperStampProps): React.ReactNode
	-- Called unconditionally (hook order); only read when `pop` is set.
	local alpha = usePaperMotion(MOTION.popSeconds)
	local color = props.color or UIPaperConstants.COLOR.stamp
	local size = props.size

	local children: { [string]: React.ReactNode } = {
		stroke = e("UIStroke", {
			Color = color,
			Thickness = math.max(3, math.floor(size / 10)),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, size / 4),
			PaddingRight = UDim.new(0, size / 4),
			PaddingTop = UDim.new(0, size / 8),
			PaddingBottom = UDim.new(0, size / 8),
		}),
		label = e(PaperLabel, {
			text = props.text,
			role = "heading",
			size = size,
			color = color,
			fit = true,
		}),
	}
	if props.pop == true then
		children.scale = e("UIScale", {
			Scale = alpha:map(function(value: number): number
				return MOTION.popFrom + (1 - MOTION.popFrom) * value
			end),
		})
	end

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		AnchorPoint = props.anchor,
		Position = props.position,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Rotation = props.tilt or UIPaperConstants.STAMP_TILT,
		BackgroundTransparency = 1,
	}, children)
end

return PaperStamp
