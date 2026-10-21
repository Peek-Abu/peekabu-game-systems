--!strict
--[=[
	CargoPriceTag: a cargo item's price tag in the V1 kit at its 260x70 design size: a cream capsule on the depth stack
	(small chrome, the sparkle pattern), the name in Fredoka (shrinking to fit the longest catalog name) and the price as
	a stroked gold number on the right (coral once cracked), with the coin render breaking the tag's top-right
	corner. The mark (FRAGILE, CRACKED −50%, 62% CLEAN) is a small pill under the name: coral once cracked or grime
	locked, sky otherwise. An appraised valuable wears a tilted mint APPRAISED sticker at the tag's lower right, popping
	in when the appraisal is fresh. Presentational; the words are CargoWorldViewModel.priceTag.

	@class CargoPriceTag
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoWorldViewModel = require(ReplicatedStorage.Client.UI.React.Screens.World.CargoWorldViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonMotionViewModel = require(Toon.ToonMotionViewModel)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)

local e = React.createElement

export type CargoPriceTagProps = {
	view: CargoWorldViewModel.PriceTagView,
}

local SIZE = CargoConstants.LABEL_PX
-- The tag's own drop (small chrome) stays inside the design box.
local BODY = Vector2.new(SIZE.X - 8, SIZE.Y - 8)
local PRICE_WIDTH = 104
local COIN = 34

-- The APPRAISED sticker; it pops in once when the appraisal is fresh.
local function Appraised(props: { pop: boolean }): React.ReactNode
	local alpha = useToonPlay(if props.pop then UIToonConstants.MOTION.popSeconds else 0, 0, nil)
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, 2),
		Size = UDim2.fromOffset(104, 24),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, {
		pop = e("UIScale", {
			Scale = alpha:map(function(value: number): number
				return if props.pop then ToonMotionViewModel.pop(value) else 1
			end),
		}),
		pill = e(ToonPill, {
			text = "APPRAISED",
			hue = "mint",
			textSize = 13,
			tilt = -6,
			size = UDim2.fromScale(1, 1),
		}),
	})
end

local function CargoPriceTag(props: CargoPriceTagProps): React.ReactNode
	local view = props.view
	local mark = view.mark
	local face: { [string]: React.ReactNode } = {
		name = e(ToonText, {
			text = view.name,
			font = "body",
			textSize = 20,
			position = UDim2.fromOffset(14, if mark ~= nil then 4 else 0),
			size = UDim2.new(1, -PRICE_WIDTH - 22, if mark ~= nil then 0 else 1, if mark ~= nil then 26 else 0),
			fit = true,
		}),
		price = e(ToonText, {
			text = view.price,
			meaning = if view.cracked then "coral" else "gold",
			textSize = 26,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -12, 0, 0),
			size = UDim2.new(0, PRICE_WIDTH, 1, 0),
			align = "right",
			fit = true,
		}),
	}
	if mark ~= nil then
		local warn = view.cracked or string.find(mark, "LOCKED", 1, true) ~= nil
		face.mark = e(ToonPill, {
			text = mark,
			hue = if warn then "coral" else "sky",
			textSize = 12,
			position = UDim2.fromOffset(12, 31),
			size = UDim2.fromOffset(math.min(BODY.X - PRICE_WIDTH - 20, 24 + (utf8.len(mark) or #mark) * 8), 20),
		})
	end
	local nodes: { [string]: React.ReactNode } = {
		tag = e(ToonSurface, {
			hue = "cream",
			small = true,
			radius = 20,
			pattern = "sparkle",
			position = UDim2.fromOffset(2, 6),
			size = UDim2.fromOffset(BODY.X, BODY.Y - 4),
			children = face,
		}),
		-- The coin render breaks the tag's top-right corner, over the price.
		coin = e(ToonIcon, {
			icon = "gleam",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(BODY.X - 6, 10),
			size = UDim2.fromOffset(COIN, COIN),
			drop = 3,
			zIndex = 5,
		}),
	}
	if view.appraised then
		-- Keyed by `pop` so a fresh appraisal mounts a new sticker (it pops once on mount).
		nodes[if view.pop then "appraisedFresh" else "appraised"] = e(Appraised, { pop = view.pop })
	end
	return e("Frame", {
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		BackgroundTransparency = 1,
	}, nodes)
end

return CargoPriceTag
