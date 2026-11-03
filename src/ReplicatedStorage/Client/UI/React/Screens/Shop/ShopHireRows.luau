--!strict
--[=[
	ShopHireRows: the middle of an employee's hire page in the Shop (ShopProductPanel), in place of the "inside" list:
	the ability card (its render breaking the left edge, the cooldown on a cream chip), a STATS heading and the five
	stats on a dark plate, the same rows as the About tab (ToonStatRows). Rows for the panel's list, in order, sized to
	fit `height` (the list's height) so all five stats show without scrolling; a short screen drops the ability card
	first, and only a very short one scrolls. All of it is ShopViewModel.product (`ability`, `stats`). Presentational
	(exempt; story in ShopScreen.story).

	@class ShopHireRows
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonPill = require(Toon.ToonPill)
local ToonStatRows = require(Toon.ToonStatRows)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

local ShopHireRows = {}

function ShopHireRows.rows(product: VM.Product, size: number, phone: boolean, height: number): Nodes
	local rows: Nodes = {}
	-- The rows share what is left once the card, the heading, the list's gaps and the plate's padding are in. On a
	-- screen too short for both, the ability card goes (it is also on the pick card and the About tab) so the five
	-- stats stay readable.
	local cardHeight = if phone then 44 else 76
	local minRow = if phone then 14 else 26
	local count = math.max(#product.stats, 1)
	local base = (size + 8) + 3 * (if phone then 4 else 8) + (if phone then 16 else 32) + DEPTH.drop
	local function rowFor(withCard: boolean): number
		local used = base + (if withCard then cardHeight + DEPTH.drop else 0)
		return math.floor((height - used) / count)
	end
	local ability = product.ability
	if ability ~= nil and rowFor(true) < minRow then
		ability = nil
	end
	local row = math.clamp(rowFor(ability ~= nil), minRow, if phone then 20 else 44)
	if ability ~= nil then
		local art = math.floor(cardHeight * 0.95)
		local face: Nodes = {
			name = e(ToonText, {
				text = ability.name,
				textSize = size + 6,
				position = UDim2.fromOffset(art + 4, if phone then 4 else 10),
				size = UDim2.new(1, -art - 90, 0, size + 10),
				fit = true,
			}),
			line = e(ToonText, {
				text = ability.line,
				font = "body",
				color = COLOR.white,
				textSize = size - 2,
				position = UDim2.fromOffset(art + 4, size + (if phone then 14 else 24)),
				size = UDim2.new(1, -art - 90, 0, size),
				fit = true,
			}),
			cooldown = e(ToonPill, {
				text = ability.cooldown,
				hue = "cream",
				textSize = size - 2,
				anchor = Vector2.new(1, 0.5),
				position = UDim2.new(1, -12, 0.5, -4),
				size = UDim2.fromOffset(if phone then 46 else 74, if phone then 32 else 56),
			}),
			art = e(ToonIcon, {
				image = UIAssets.iconImage(ability.icon),
				anchor = Vector2.new(0, 0.5),
				position = UDim2.new(0, 2, 0.5, -4),
				size = UDim2.fromOffset(art, art),
				drop = 3,
			}),
		}
		rows.ability = e("Frame", {
			Size = UDim2.new(1, 0, 0, cardHeight + DEPTH.drop),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}, {
			card = e(ToonSurface, {
				hue = "grape",
				radius = 18,
				size = UDim2.new(1, 0, 0, cardHeight),
				children = face,
			}),
		})
	end
	rows.heading = e(ToonText, {
		text = "STATS",
		textSize = size + 2,
		meaning = "grape",
		size = UDim2.new(1, 0, 0, size + 8),
		layoutOrder = 2,
		fit = true,
	})
	local plate = row * #product.stats + (if phone then 16 else 32)
	local statsFace: Nodes = {
		rows = e(ToonStatRows, {
			rows = product.stats,
			row = row,
			barX = if phone then 104 else 190,
			textSize = size,
			position = UDim2.fromOffset(14, if phone then 8 else 16),
			size = UDim2.new(1, -28, 0, row * #product.stats),
		}),
	}
	rows.stats = e("Frame", {
		Size = UDim2.new(1, 0, 0, plate + DEPTH.drop),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, {
		plate = e(ToonSurface, {
			hue = "night",
			pattern = "bubbles",
			radius = 18,
			size = UDim2.new(1, 0, 0, plate),
			children = statsFace,
		}),
	})
	return rows
end

return ShopHireRows
