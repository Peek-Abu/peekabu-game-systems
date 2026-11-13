--!strict
--[=[
	DepotPlaceCard: one photo card on the places menu (DepotBoardPanel; p1-places-menu), from our own posed scene shots:
	the place's photo under an ink scrim with its name and site, its DANGER meter (Gloom drops filled to the place's
	level; the label on desktop only), and a sticker tag (TONIGHT!, OPEN, LOCKED or SOON). A locked place is darkened
	with Gloom pooled in the photo's floor and the padlock render; a place that can be bought adds the gold BUY with its
	Credits price (SURE? on the second tap, `onBuy`). The whole card is a tap target under the BUY: the host's tap on an
	open place picks it (`onPick`), anyone else's shows it (`onView`). The focused card wears V2's lilac ring and a
	pointer to the detail. Presentational (exempt): it draws the BuildingView it is given (specced in
	DepotBoardViewModel).

	@class DepotPlaceCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local DepotBoardViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotBoardViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonGoo = require(Toon.ToonGoo)
local ToonIcon = require(Toon.ToonIcon)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

type Nodes = { [string]: React.ReactNode }

-- What a card's taps call (DepotBoardPanel passes its own props through).
export type Handlers = {
	onPick: ((map: ShiftTypes.MapId) -> ())?,
	onView: ((map: ShiftTypes.MapId) -> ())?,
	-- `gleam`: the Gleam the button offered for the rest (0: Credits only).
	onBuy: ((map: ShiftTypes.MapId, gleam: number) -> ())?,
}

local function photoOf(photo: DepotBoardViewModel.Photo): string
	local photos = UIAssets.toonPhotos
	if photo == "school" then
		-- The School's posed Studio shot (Bramble in a locker hall).
		return photos.schoolCard
	elseif photo == "hospital" then
		return photos.hospitalCard
	elseif photo == "motel" then
		return photos.motelCard
	elseif photo == "mall" then
		return photos.mallCard
	end
	return photos.officeCard
end

-- The DANGER meter: the label (desktop; a phone card is too small for it to read) over `max` Gloom drops, the first
-- `level` full, the rest greyed and faint.
local function dangerMeter(label: string, level: number, max: number, phone: boolean, position: UDim2): React.ReactNode
	local drop = if phone then 15 else 30
	local gap = if phone then 1 else 3
	local top = if phone then 0 else 20
	local nodes: Nodes = {}
	if not phone then
		nodes.label = e(ToonText, {
			text = label,
			textSize = 17,
			size = UDim2.fromOffset(max * (drop + gap), top),
			fit = true,
			zIndex = 5,
		})
	end
	for index = 1, max do
		local full = index <= level
		nodes[`drop{index}`] = e(ToonIcon, {
			icon = "gloom",
			position = UDim2.fromOffset((index - 1) * (drop + gap), top),
			size = UDim2.fromOffset(drop, drop),
			drop = if full then (if phone then 1 else 3) else 0,
			greyed = not full,
			transparency = if full then 0 else 0.55,
			zIndex = 5,
		})
	end
	return e("Frame", {
		Position = position,
		Size = UDim2.fromOffset(max * (drop + gap), drop + top),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, nodes)
end

local function DepotPlaceCard(
	building: DepotBoardViewModel.BuildingView,
	view: DepotBoardViewModel.BoardView,
	props: Handlers,
	phone: boolean,
	size: Vector2,
	position: UDim2
): React.ReactNode
	local inset = if phone then 5 else 12
	local photoSize = Vector2.new(size.X - 2 * inset, size.Y - 2 * inset - (if phone then 4 else 8))
	local radius = if phone then 12 else 20
	local photo: Nodes = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
		stroke = e("UIStroke", { Color = COLOR.ink, Thickness = if phone then 3 else 4 }),
		scrim = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.6),
			BackgroundColor3 = COLOR.ink,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
			gradient = e("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.1) }),
		}),
		name = e(ToonText, {
			text = building.name,
			textSize = if phone then 13 else 30,
			position = UDim2.new(0, if phone then 6 else 16, 1, if phone then -40 else -96),
			size = UDim2.new(1, if phone then -12 else -32, 0, if phone then 18 else 40),
			fit = true,
			zIndex = 4,
		}),
		site = e(ToonText, {
			text = building.site,
			font = "body",
			color = COLOR.white,
			textSize = if phone then 12 else 20,
			position = UDim2.new(0, if phone then 7 else 18, 1, if phone then -22 else -56),
			size = UDim2.new(1, if phone then -14 else -36, 0, if phone then 15 else 26),
			fit = true,
			zIndex = 4,
		}),
	}
	local danger = building.danger
	if danger ~= nil then
		photo.danger = dangerMeter(
			view.dangerLabel,
			danger,
			view.dangerMax,
			phone,
			UDim2.fromOffset(if phone then 6 else 14, if phone then 5 else 12)
		)
	end
	if not building.open then
		-- The Gloom pooled inside the photo's floor (clear of its rounded corners), a padlock, and the photo darkened.
		local buy = building.buy
		photo.dark = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.ink,
			BackgroundTransparency = if buy ~= nil then 0.55 else 0.45,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }) })
		photo.goo = e(ToonGoo, {
			kind = "pool",
			width = photoSize.X,
			radius = radius,
			scale = if phone then 0.4 else 0.8,
			zIndex = 3,
		})
		-- With a BUY the padlock shrinks and rises so the button and its note clear the place's name (play check 11-13).
		-- A phone card with a BUY has no room for the padlock too: the button says it is locked.
		local lockSide = if buy ~= nil then 50 else (if phone then 30 else 110)
		photo.lock = if buy ~= nil and phone
			then nil
			else e(ToonIcon, {
				icon = "lock",
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, if buy ~= nil then 0.27 else (if phone then 0.28 else 0.36)),
				size = UDim2.fromOffset(lockSide, lockSide),
				drop = if phone then 3 else 6,
				zIndex = 5,
			})
	end
	local face: Nodes = {
		photo = e("ImageLabel", {
			Position = UDim2.fromOffset(inset, inset),
			Size = UDim2.fromOffset(photoSize.X, photoSize.Y),
			BackgroundColor3 = COLOR.ink,
			Image = photoOf(building.photo),
			ScaleType = Enum.ScaleType.Crop,
		}, photo),
	}
	local nodes: Nodes = {
		card = e(ToonSurface, {
			hue = "night",
			size = UDim2.fromScale(1, 1),
			radius = if phone then 14 else 26,
			pattern = "bubbles",
			gloss = false,
			pose = nil,
			children = face,
		}),
		tag = e(ToonPill, {
			text = building.tag,
			hue = if building.picked then "mint" elseif building.open then "sky" else "lilac",
			textSize = if phone then 12 else 22,
			tilt = if building.picked then 6 else 4,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, if phone then 6 else 12, 0, if phone then 4 else 8),
			size = UDim2.fromOffset(if phone then 62 else 140, if phone then 20 else 42),
			zIndex = 6,
		}),
	}
	local cardMap: ShiftTypes.MapId? = building.map
	if cardMap ~= nil then
		local map: ShiftTypes.MapId = cardMap
		-- The whole card is a tap target (under the BUY): the host's tap on an open place picks it, anyone's shows it.
		nodes.tap = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 7,
			[React.Event.Activated] = function()
				if building.canPick and props.onPick ~= nil then
					props.onPick(map)
				elseif props.onView ~= nil then
					props.onView(map)
				end
			end,
		})
		local buy = building.buy
		if buy ~= nil then
			nodes.buy = e(ToonButton, {
				variant = if buy.confirming then "primary" else "gleam",
				icon = if not buy.enabled or buy.confirming then nil elseif buy.gleam > 0 then "gleam" else "credits",
				text = if buy.enabled
						and not buy.confirming
						and buy.gleam == 0
					then `{buy.text} · {buy.price}`
					else buy.text,
				textSize = if phone then 12 else 22,
				small = phone,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, if phone then 0.42 else 0.44),
				size = UDim2.new(1, if phone then -10 else -24, 0, if phone then 24 else 48),
				disabled = not buy.enabled,
				selected = buy.confirming,
				sound = if buy.confirming then "cta" else nil,
				zIndex = 8,
				onActivated = function()
					if buy.enabled and props.onBuy ~= nil then
						props.onBuy(map, buy.gleam)
					end
				end,
			})
			local note = buy.note
			if note ~= nil and not phone then
				nodes.note = e(ToonText, {
					text = note,
					font = "body",
					color = COLOR.white,
					textSize = 17,
					anchor = Vector2.new(0.5, 0),
					position = UDim2.new(0.5, 0, 0.44, 28),
					size = UDim2.new(1, -24, 0, 22),
					align = "center",
					fit = true,
					zIndex = 8,
				})
			end
		end
	end
	if building.focused then
		-- Focused: V2's lilac ring and glow, lifted, with a pointer down to the detail.
		nodes.ring = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, if phone then 10 else 22, 1, if phone then 12 else 24),
			BackgroundTransparency = 1,
			ZIndex = 0,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, if phone then 18 else 34) }),
			stroke = e("UIStroke", { Color = COLOR.selected, Thickness = if phone then 4 else 7 }),
		})
		nodes.pointer = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, if phone then 10 else 22),
			Size = UDim2.fromOffset(if phone then 12 else 26, if phone then 12 else 26),
			Rotation = 45,
			BackgroundColor3 = COLOR.selected,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, { stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }) })
	end
	return e("Frame", {
		Position = position,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, nodes)
end

return DepotPlaceCard
