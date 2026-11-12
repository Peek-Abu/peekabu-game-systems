--!strict
--[=[
	DepotTopper: a hub station's topper in the V1 kit (owner 11-12, kit mock round 2 #1), drawn on a SurfaceGui the size
	of DepotSpotConstants.TOPPER.PLATE: a kit plate (the full depth stack) in the station's colour across the lower
	half, its rendered icon standing on it and breaking its top edge, and one stroked word. Readable from across the
	room by the icon and the colour before the word. Presentational.

	@class DepotTopper
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local DepotTopperConstants = require(ReplicatedStorage.Client.Features.Depot.Data.DepotTopperConstants)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)

local e = React.createElement

export type DepotTopperProps = {
	station: DepotTopperConstants.Station,
}

local TOPPER = DepotSpotConstants.TOPPER
local CANVAS = TOPPER.PLATE * TOPPER.PIXELS_PER_STUD
local BODY = CANVAS.Y * TOPPER.BODY_SHARE
-- The icon's side, and how far it drops into the plate (so it stands on it, breaking its top edge).
local ICON = CANVAS.Y * 0.62
local SINK = ICON * 0.3
local INSET = 10

local function DepotTopper(props: DepotTopperProps): React.ReactNode
	local station = props.station
	local face: { [string]: React.ReactNode } = {
		word = e(ToonText, {
			text = station.word,
			meaning = "white",
			textSize = 44,
			align = "center",
			position = UDim2.fromOffset(10, SINK - 6),
			size = UDim2.new(1, -20, 1, -SINK - 2),
			fit = true,
		}),
	}
	return e("Frame", { Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y), BackgroundTransparency = 1 }, {
		plate = e(ToonSurface, {
			hue = station.hue,
			radius = 26,
			pattern = "sparkle",
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -INSET),
			size = UDim2.fromOffset(CANVAS.X - 2 * INSET, BODY),
			children = face,
		}),
		icon = e(ToonIcon, {
			icon = station.icon,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -INSET - BODY + SINK),
			size = UDim2.fromOffset(ICON, ICON),
			zIndex = 4,
		}),
	})
end

return DepotTopper
