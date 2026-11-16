--!strict
--[=[
	CharacterPickAboutCard: the pick screen's About card (CharacterPickScreen): who the employee is, the five gold stat
	bars, and the ability card with its render and cooldown chip. Values: EmployeeProfileRegistry and
	InventoryViewModel.stats. Split out of CharacterPickScreen. Presentational (exempt).

	@class CharacterPickAboutCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonCooldown = require(Toon.ToonCooldown)
local ToonStatRows = require(Toon.ToonStatRows)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

local function CharacterPickAboutCard(
	employee: string,
	layout: InventoryViewModel.Layout,
	height: number
): React.ReactNode
	local profile = EmployeeProfileRegistry.get(employee)
	if profile == nil then
		return nil
	end
	local phone = layout.phone
	local size = layout.textSize
	local face: Nodes = {}
	local y = if phone then 10 else 20
	face.title = e(ToonText, {
		text = `ABOUT {string.upper(employee)}`,
		textSize = size + 10,
		position = UDim2.fromOffset(20, y),
		size = UDim2.new(1, -40, 0, size + 14),
		fit = true,
	})
	y += size + 18
	face.bio = e(ToonText, {
		text = profile.bio,
		font = "body",
		color = COLOR.white,
		textSize = size,
		position = UDim2.fromOffset(20, y),
		size = UDim2.new(1, -40, 0, size * 3),
		wrapped = true,
		fit = true,
		alignY = "top",
	})
	y += size * 3 + 8
	local abilityHeight = if phone then 64 else 120
	local row = math.clamp(
		math.floor((height - y - abilityHeight - 30 - DEPTH.drop) / 5),
		if phone then 18 else 30,
		if phone then 26 else 54
	)
	local barX = if phone then 110 else 200
	face.stats = e(ToonStatRows, {
		rows = InventoryViewModel.stats(employee),
		row = row,
		barX = barX + 4,
		textSize = size,
		position = UDim2.fromOffset(16, y),
		size = UDim2.new(1, -36, 0, row * 5),
	})
	-- The ability card at the foot, its render breaking the left edge, the cooldown on a round chip.
	local art = math.floor(abilityHeight * 1.05)
	local ability: Nodes = {
		name = e(ToonText, {
			text = profile.ability.name,
			textSize = size + 10,
			position = UDim2.fromOffset(math.floor(art * 0.7), 8),
			size = UDim2.new(1, -math.floor(art * 0.7) - 90, 0, size + 14),
			fit = true,
		}),
		line = e(ToonText, {
			text = profile.ability.line,
			font = "body",
			color = COLOR.white,
			textSize = size - 2,
			position = UDim2.fromOffset(math.floor(art * 0.7), size + 24),
			size = UDim2.new(1, -math.floor(art * 0.7) - 90, 0, size + 4),
			fit = true,
		}),
		cooldown = e(ToonCooldown, {
			seconds = profile.ability.cooldown,
			height = if phone then 46 else 72,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -14, 0.5, -2),
			size = UDim2.fromOffset(if phone then 56 else 84, if phone then 46 else 72),
		}),
	}
	face.ability = e(ToonSurface, {
		hue = "grape",
		radius = 20,
		position = UDim2.fromOffset(16 + math.floor(art * 0.3), height - abilityHeight - 22 - DEPTH.drop),
		size = UDim2.new(1, -32 - math.floor(art * 0.3), 0, abilityHeight),
		children = ability,
	})
	face.abilityArt = e(ToonIcon, {
		image = UIAssets.iconImage(profile.ability.icon),
		anchor = Vector2.new(0, 0.5),
		position = UDim2.fromOffset(4, height - abilityHeight / 2 - 26 - DEPTH.drop),
		size = UDim2.fromOffset(art, art),
		drop = 4,
		zIndex = 3,
	})
	return e(ToonSurface, {
		hue = "lilac",
		shade = {
			base = UIToonConstants.shade("grape").lo,
			hi = UIToonConstants.shade("grape").base,
			lo = UIToonConstants.shade("night").base,
		},
		pattern = "bubbles",
		radius = 28,
		size = UDim2.new(1, 0, 1, -DEPTH.drop),
		children = face,
	})
end

return CharacterPickAboutCard
