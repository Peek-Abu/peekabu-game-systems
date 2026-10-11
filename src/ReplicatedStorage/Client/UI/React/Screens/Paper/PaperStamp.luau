--!strict
--[=[
	PaperStamp: a rubber stamp ("QUOTA MET"), an outlined Oswald Bold word in stamp red at a slight tilt. With `pop`
	it drops in from 140% once on mount (UIPaperConstants.MOTION); remount it (change its key) to stamp again.
	A size over 100 (Roblox caps TextSize there) is drawn at 100 and enlarged by a UIScale. Presentational.

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
-- Roblox clamps TextLabel.TextSize at 100; a bigger stamp is drawn at 100 and enlarged with its UIScale.
local MAX_TEXT_SIZE = 100

local function PaperStamp(props: PaperStampProps): React.ReactNode
	-- Called unconditionally (hook order); only read when `pop` is set.
	local alpha = usePaperMotion(MOTION.popSeconds)
	local color = props.color or UIPaperConstants.COLOR.stamp
	-- Everything below is drawn at `size` (<= 100); `enlarge` scales the whole stamp up to the requested size.
	local size = math.min(props.size, MAX_TEXT_SIZE)
	local enlarge = props.size / size

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
	if props.pop == true or enlarge ~= 1 then
		-- One UIScale only (two on a frame do not stack): the enlargement times the pop.
		children.scale = e("UIScale", {
			Scale = alpha:map(function(value: number): number
				local pop = if props.pop == true then MOTION.popFrom + (1 - MOTION.popFrom) * value else 1
				return enlarge * pop
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
