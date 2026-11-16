--!strict
--[=[
	CharacterPickCard: one employee card in the pick screen's column (CharacterPickScreen): their head breaking out of
	the card, name, line, "Free!" or the hire price, the price tag on its top-right corner when locked, and the
	selected ring. Values: CharacterPickViewModel.cards / tagFrame and InventoryViewModel.color. Split out of
	CharacterPickScreen. Presentational (exempt).

	@class CharacterPickCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonPrice = require(Toon.ToonPrice)
local ToonPressable = require(Toon.ToonPressable)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local VM = require(script.Parent.CharacterPickViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }
type Tint = { body: Color3, light: Color3, dark: Color3 }

local function shadeOf(color: Tint): UIToonConstants.Shade
	return { base = color.body, hi = color.light, lo = color.dark }
end

local function CharacterPickCard(
	entry: VM.Card,
	height: number,
	phone: boolean,
	order: number,
	onSelect: (id: string) -> ()
): React.ReactNode
	local color = InventoryViewModel.color(entry.id)
	local profile = EmployeeProfileRegistry.get(entry.id)
	local head = math.floor(height * 1.15)
	local nameSize = math.floor(height * 0.34)
	local face: Nodes = {
		name = e(ToonText, {
			text = string.upper(entry.name),
			textSize = nameSize,
			position = UDim2.fromOffset(math.floor(head * 0.78), math.floor(height * 0.12)),
			size = UDim2.new(1, -math.floor(head * 0.78) - 12, 0, nameSize + 6),
			fit = true,
		}),
	}
	if entry.locked then
		local price: Nodes = {
			price = e(ToonPrice, {
				currency = "credits",
				amount = entry.tag,
				textSize = math.floor(height * 0.2),
				align = "center",
				size = UDim2.new(1, 0, 1, -4),
			}),
		}
		face.price = e(ToonSurface, {
			hue = "night",
			radius = 999,
			small = true,
			position = UDim2.fromOffset(math.floor(head * 0.78), math.floor(height * 0.52)),
			size = UDim2.fromOffset(math.floor(height * 1.2), math.floor(height * 0.32)),
			children = price,
		})
	elseif profile ~= nil then
		face.line = e(ToonText, {
			text = profile.line,
			font = "body",
			color = COLOR.white,
			textSize = math.max(if phone then 12 else 18, math.floor(height * 0.15)),
			position = UDim2.fromOffset(math.floor(head * 0.78), math.floor(height * 0.52)),
			size = UDim2.new(1, -math.floor(head * 0.78) - 12, 0, math.floor(height * 0.2)),
			fit = true,
		})
	end
	local nodes: Nodes = {
		surface = e(ToonSurface, {
			hue = "grape",
			shade = shadeOf(color),
			radius = 22,
			position = UDim2.fromOffset(0, math.floor(height * 0.18)),
			size = UDim2.new(1, 0, 0, height),
			children = face,
			zIndex = 2,
		}),
		-- The head breaks out of the card's top-left.
		head = e(ToonViewport, {
			employee = entry.id,
			framing = "upper",
			dim = entry.locked,
			position = UDim2.fromOffset(-math.floor(head * 0.06), 0),
			size = UDim2.fromOffset(head, head),
			zIndex = 3,
		}),
	}
	if entry.selected then
		nodes.ring = e("Frame", {
			Position = UDim2.fromOffset(-8, math.floor(height * 0.18) - 8),
			Size = UDim2.new(1, 16, 0, height + DEPTH.drop + 16),
			BackgroundTransparency = 1,
			ZIndex = 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 30) }),
			stroke = e("UIStroke", { Color = COLOR.selected, Thickness = 6 }),
		})
	end
	if entry.locked then
		-- The hire tag on the row's top-right corner, where the FREE flag sits; never over the portrait (owner pick
		-- 11-15, Option 2).
		local tag = VM.tagFrame(height)
		nodes.lock = e(ToonIcon, {
			icon = "priceTag",
			anchor = tag.anchor,
			position = tag.position,
			size = UDim2.fromOffset(tag.size, tag.size),
			drop = 3,
			zIndex = 4,
		})
	else
		nodes.free = e(ToonFlag, {
			text = entry.tag,
			hue = "mint",
			tilt = 8,
			textSize = if phone then 13 else 22,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, 10, 0, math.floor(height * 0.08)),
			size = UDim2.fromOffset(if phone then 64 else 104, if phone then 24 else 38),
			zIndex = 4,
		})
	end
	return e(ToonPressable, {
		size = UDim2.new(1, 0, 0, math.floor(height * 1.18) + DEPTH.drop),
		layoutOrder = order,
		deal = order,
		onActivated = function()
			onSelect(entry.id)
		end,
		children = nodes,
	})
end

return CharacterPickCard
