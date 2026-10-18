--!strict
--[=[
	DepotNextShiftCard: the hub's "Next shift" CTA (V1 hub render), bottom-centre between the phone's thumbstick and
	Jump: a cream bar with the company truck render breaking its top-left corner, NEXT SHIFT, a line ("Walk into a truck
	bed to join", or the truck's countdown in a coral pill), a seat per place with each crew member's own character
	(desktop) and the mint GO! with Gleam sparkles. What it says is DepotPadViewModel.cta; GO! is `onGo` (the hub opens
	the Jobs board, the queue pad departs now). Presentational (exempt; story in DepotHubPanel.story).

	@class DepotNextShiftCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local DepotPadViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotPadViewModel)
local CharacterPortrait = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.CharacterPortrait)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

export type DepotNextShiftCardProps = {
	cta: DepotPadViewModel.CtaView,
	phone: boolean,
	onGo: () -> (),
}

type Geometry = {
	size: Vector2,
	bottom: number,
	truck: number,
	textLeft: number,
	title: number,
	line: number,
	go: Vector2,
	seat: number,
}

local DESKTOP: Geometry = {
	size = Vector2.new(940, 140),
	bottom = 26,
	truck = 300,
	textLeft = 252,
	title = 48,
	line = 22,
	go = Vector2.new(150, 86),
	seat = 52,
}
local PHONE: Geometry = {
	size = Vector2.new(430, 72),
	bottom = 10,
	truck = 156,
	textLeft = 128,
	title = 28,
	line = 15,
	go = Vector2.new(92, 54),
	seat = 0,
}

local function seat(view: DepotPadViewModel.SeatView, side: number, order: number): React.ReactNode
	local children: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		stroke = e("UIStroke", {
			Color = if view.you then COLOR.selected else COLOR.ink,
			Thickness = if view.you then 5 else 4,
		}),
	}
	if not view.open and view.userId ~= nil then
		children.face = e(CharacterPortrait, {
			userId = view.userId,
			context = "crew",
			framing = "head",
			size = UDim2.fromScale(1, 1),
			round = true,
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = if view.open then UIToonConstants.shade("cream").base else UIToonConstants.shade("lilac").hi,
		BackgroundTransparency = if view.open then 1 else 0,
		LayoutOrder = order,
	}, children)
end

local function DepotNextShiftCard(props: DepotNextShiftCardProps): React.ReactNode
	local cta = props.cta
	local g = if props.phone then PHONE else DESKTOP
	local height = g.size.Y
	local lineChildren: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		text = e(ToonText, {
			text = cta.line,
			font = "body",
			textSize = g.line,
			size = UDim2.fromScale(0, 1),
			automaticWidth = true,
			layoutOrder = 1,
		}),
	}
	if cta.time ~= nil then
		lineChildren.time = e(ToonPill, {
			text = cta.time,
			hue = "coral",
			textSize = math.floor(g.line * 1.25),
			size = UDim2.fromOffset(g.line * 3.6, g.line * 1.7),
			layoutOrder = 2,
		})
	end
	-- The seats sit between the line and GO!; the line and title stop short of them.
	local seatsWidth = if g.seat > 0 and #cta.seats > 0 then #cta.seats * (g.seat + 8) + 6 else 0
	local textWidth = g.size.X - g.textLeft - g.go.X - 32 - seatsWidth
	local face: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = cta.title,
			textSize = g.title,
			position = UDim2.fromOffset(g.textLeft, if props.phone then 4 else 14),
			size = UDim2.fromOffset(textWidth, g.title + 8),
			fit = true,
		}),
		line = e("Frame", {
			Position = UDim2.fromOffset(g.textLeft, if props.phone then 38 else 74),
			Size = UDim2.fromOffset(textWidth, if props.phone then 26 else 44),
			BackgroundTransparency = 1,
		}, lineChildren),
		go = e(ToonButton, {
			variant = "primary",
			text = cta.go,
			textSize = if props.phone then 34 else 50,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -16, 0.5, -2),
			size = UDim2.fromOffset(g.go.X, g.go.Y),
			disabled = not cta.canGo,
			sound = "cta",
			onActivated = props.onGo,
			zIndex = 4,
		}),
	}
	if g.seat > 0 and #cta.seats > 0 then
		local seats: { [string]: React.ReactNode } = {
			layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index, view in cta.seats do
			seats[`seat{index}`] = seat(view, g.seat, index)
		end
		face.seats = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -g.go.X - 30, 0.5, 4),
			Size = UDim2.fromOffset(seatsWidth, g.seat + 8),
			BackgroundTransparency = 1,
		}, seats)
	end
	local truckSize = g.truck
	face.truck = e(ToonIcon, {
		image = UIAssets.toonPhotos.truckCut,
		position = UDim2.fromOffset(-truckSize * 0.2, height - truckSize * 0.92),
		size = UDim2.fromOffset(truckSize, truckSize * 0.82),
		drop = 6,
		zIndex = 3,
	})
	face.sparkles = e(ToonSparkle, {
		spots = {
			{ position = UDim2.fromOffset(truckSize * 0.92, 0), size = if props.phone then 22 else 36 },
			{ position = UDim2.new(1, -g.go.X - 6, 0, -6), size = if props.phone then 18 else 30 },
			{ position = UDim2.new(1, -g.go.X * 0.4, 0, 4), size = if props.phone then 14 else 24 },
		},
		zIndex = 6,
	})
	return e(ToonPanel, {
		size = g.size,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -g.bottom),
		radius = if props.phone then 20 else 26,
		children = face,
	})
end

return DepotNextShiftCard
