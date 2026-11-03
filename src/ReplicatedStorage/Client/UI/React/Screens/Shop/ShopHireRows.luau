--!strict
--[=[
	ShopHireRows: the middle of an employee's hire page in the Shop (ShopProductPanel), in place of the "inside" list:
	the ability card (its render breaking the left edge, the cooldown on a cream chip), a STATS heading and the five
	stats on a dark plate, the same rows as the About tab (ToonStatRows). Rows for the panel's list, in order. All of
	it is ShopViewModel.product (`ability`, `stats`). Presentational (exempt; story in ShopScreen.story).

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

function ShopHireRows.rows(product: VM.Product, size: number, phone: boolean): Nodes
	local rows: Nodes = {}
	local ability = product.ability
	if ability ~= nil then
		local height = if phone then 52 else 96
		local art = math.floor(height * 0.95)
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
			Size = UDim2.new(1, 0, 0, height + DEPTH.drop),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}, {
			card = e(ToonSurface, {
				hue = "grape",
				radius = 18,
				size = UDim2.new(1, 0, 0, height),
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
	local row = if phone then 20 else 44
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
