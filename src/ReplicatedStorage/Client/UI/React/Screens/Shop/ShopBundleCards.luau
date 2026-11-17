--!strict
--[=[
	ShopBundleCards: the Gleam bundles' cards: `row` lays them side by side (the Featured tab's short cards along the
	bottom, the Gleam tab's tall ones on a desktop); `ladder` is the Gleam tab's tall cards, a sideways scroll on a
	phone. A card has the pack's picture, its amount, its Robux price button (greyed "Soon" until its product exists),
	a corner tag ("Just right!", POPULAR, BEST VALUE) and a bonus burst. Values: ShopViewModel.bundles. Split out of
	ShopScreen. Presentational (exempt).

	@class ShopBundleCards
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBurst = require(Toon.ToonBurst)
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local ShopScreenBlocks = require(script.Parent.ShopScreenBlocks)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local DEPTH = UIToonConstants.DEPTH

type Nodes = ShopScreenBlocks.Nodes

local group = ShopScreenBlocks.group

local function bundleCard(
	bundle: VM.Bundle,
	size: Vector2,
	phone: boolean,
	order: number,
	onBuy: (key: string) -> ()
): React.ReactNode
	-- Tall cards (the Gleam tab) stack the render, the amount and the price; short ones (the Featured row) put the
	-- render on the left and the amount over the price on the right.
	local wide = size.Y < size.X * 0.62
	local amountSize = if phone then 18 else 40
	local pillHeight = if phone then (if wide then 22 else 28) else (if wide then 44 else 52)
	local face: Nodes
	if wide then
		local artSize = math.floor((size.Y - DEPTH.drop - DEPTH.lip) * 0.92)
		face = {
			icon = e(ToonIcon, {
				image = bundle.image,
				anchor = Vector2.new(0, 0.5),
				position = UDim2.new(0, 8, 0.5, -DEPTH.lip / 2),
				size = UDim2.fromOffset(artSize, artSize),
				drop = 4,
				greyed = not bundle.available,
			}),
			amount = e(ToonText, {
				text = bundle.amount,
				textSize = amountSize,
				meaning = "white",
				position = UDim2.fromOffset(artSize + 14, 6),
				size = UDim2.new(1, -artSize - 24, 0, amountSize + 4),
				align = "center",
				fit = true,
			}),
			robux = e(ToonButton, {
				variant = if bundle.available then "primary" else "secondary",
				text = if bundle.available then bundle.robux else "Soon",
				textSize = if phone then 12 else 22,
				disabled = not bundle.available,
				small = true,
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0, artSize + 14 + math.floor((size.X - artSize - 24) / 2), 1, -DEPTH.lip - 6),
				size = UDim2.fromOffset(math.floor((size.X - artSize - 24) * 0.8), pillHeight),
				onActivated = function()
					onBuy(bundle.key)
				end,
			}),
		}
	else
		-- The Gleam tab (owner 11-16, Gleam page round 5): a tall card, the amount on top with its bonus under it, the
		-- pack's picture in the middle (bigger for a bigger pack, VM iconScale) and the price at the bottom.
		-- Bigger words than the Featured row's short cards (checked in Play 11-16: 40 read small at 75%), and nothing
		-- under the phone floor (12 pt).
		local bigSize = if phone then 24 else 56
		-- The amount sits just under the round bonus badge on the top-right corner (owner 11-16: "I did like the
		-- banner / circular bonus and percentage"), so the badge never covers it; every card lines up the same.
		local top = if phone then 24 else 56
		local amountH = bigSize + 4
		local wordSize = if phone then 12 else 22
		local artTop = top + amountH + wordSize + (if phone then 6 else 14)
		local artBottom = DEPTH.lip + pillHeight + (if phone then 10 else 20)
		local room = math.max(size.Y - DEPTH.drop - artTop - artBottom, 0)
		local artSize = math.floor(math.min(room, (size.X - 16) * bundle.iconScale))
		face = {
			amount = e(ToonText, {
				text = bundle.amount,
				textSize = bigSize,
				meaning = "gold",
				anchor = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, top),
				size = UDim2.new(1, -16, 0, amountH),
				align = "center",
				fit = true,
			}),
			word = e(ToonText, {
				text = "GLEAM",
				textSize = wordSize,
				anchor = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, top + amountH),
				size = UDim2.new(1, -16, 0, wordSize + 2),
				align = "center",
			}),
			icon = e(ToonIcon, {
				image = bundle.image,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.new(0.5, 0, 0, artTop + math.floor(room / 2)),
				size = UDim2.fromOffset(artSize, artSize),
				drop = 4,
				greyed = not bundle.available,
			}),
			robux = e(ToonButton, {
				variant = if bundle.available then "primary" else "secondary",
				text = if bundle.available then bundle.robux else "Soon",
				textSize = if phone then 15 else 30,
				disabled = not bundle.available,
				small = true,
				anchor = Vector2.new(0.5, 1),
				position = UDim2.new(0.5, 0, 1, -DEPTH.lip - 6),
				size = UDim2.fromOffset(math.floor(size.X * 0.76), pillHeight),
				onActivated = function()
					onBuy(bundle.key)
				end,
			}),
		}
	end
	local nodes: Nodes = {
		surface = e(ToonSurface, {
			-- The Gleam tab's cards climb blue, purple, gold with the pack; the Featured row keeps sky.
			hue = if wide then "sky" else bundle.hue,
			pattern = if wide then nil else "bubbles",
			radius = 20,
			small = phone,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		}),
	}
	-- The corner tag: "Just right!" for the pack the player came for, else POPULAR / BEST VALUE (the Gleam tab).
	local tag = if bundle.best then "Just right!" elseif not wide then bundle.tag else nil
	if tag ~= nil then
		nodes.best = e(ToonFlag, {
			text = tag,
			hue = if bundle.best then "mint" else "coral",
			tilt = -5,
			textSize = if phone then 12 else 20,
			position = UDim2.fromOffset(-6, -10),
			size = UDim2.fromOffset(if phone then 90 else 170, if phone then 22 else 36),
			zIndex = 6,
		})
	end
	if bundle.bonus ~= nil then
		nodes.bonus = e(ToonBurst, {
			text = bundle.bonus,
			sub = "BONUS",
			hue = "mint",
			size = if phone then (if wide then 46 else 62) else if wide then 84 else 96,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, 12, 0, -14),
			zIndex = 5,
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, nodes)
end

-- `onBuy` opens Roblox's purchase prompt for a bundle (nothing in the story).
local function bundleRow(
	width: number,
	height: number,
	phone: boolean,
	gap: number,
	bundles: { VM.Bundle },
	onBuy: (key: string) -> ()
): React.ReactNode
	local nodes: Nodes = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local cardWidth = math.floor((width - (#bundles - 1) * gap) / #bundles)
	for index, bundle in bundles do
		nodes[bundle.key] = bundleCard(bundle, Vector2.new(cardWidth, height), phone, index, onBuy)
	end
	return group(nodes)
end

-- The Gleam tab (owner 11-16: "more like marvel rivals: Dont make it stretched on top of each other"): every pack
-- side by side as a tall card. On a phone the row scrolls sideways, about four cards in view.
local function bundleLadder(
	width: number,
	height: number,
	phone: boolean,
	gap: number,
	bundles: { VM.Bundle },
	onBuy: (key: string) -> ()
): React.ReactNode
	if not phone then
		return bundleRow(width, height, phone, gap, bundles, onBuy)
	end
	local cardWidth = math.floor((width - 3 * gap) / 4.3)
	local nodes: Nodes = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Room for the corner tags and the last card's drop.
		pad = e(
			"UIPadding",
			{ PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8) }
		),
	}
	for index, bundle in bundles do
		nodes[bundle.key] = bundleCard(bundle, Vector2.new(cardWidth, height - 20), phone, index, onBuy)
	end
	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
	}, nodes)
end

return {
	row = bundleRow,
	ladder = bundleLadder,
}
