--!strict
--[=[
	InventoryAboutColumns: the About tab of an Inventory character page (InventoryCharacterPanel), as its left and right
	columns: who the employee is and a fun fact; the ability card (its render breaking the left edge), the stat bars
	and "Every employee can finish every job, even alone." Values: EmployeeProfileRegistry and
	InventoryViewModel.stats. Split out of InventoryCharacterPanel. Presentational (exempt).

	@class InventoryAboutColumns
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonIcon = require(Toon.ToonIcon)
local ToonCooldown = require(Toon.ToonCooldown)
local ToonPill = require(Toon.ToonPill)
local ToonStatRows = require(Toon.ToonStatRows)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local InventoryPanelBlocks = require(script.Parent.InventoryPanelBlocks)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type InventoryCharacterPanelProps = InventoryPanelBlocks.InventoryCharacterPanelProps
type Nodes = InventoryPanelBlocks.Nodes

local body = InventoryPanelBlocks.body
local group = InventoryPanelBlocks.group
local stack = InventoryPanelBlocks.stack
local block = InventoryPanelBlocks.block

-- A grape card on the About tab: a title and the blocks under it.
local function aboutCard(title: string, size: number, inner: Nodes, height: number, order: number): React.ReactNode
	local rows: Nodes = {
		title = block(
			size + 12,
			0,
			e(ToonText, { text = string.upper(title), textSize = size + 8, size = UDim2.fromScale(1, 1), fit = true })
		),
	}
	for key, node in inner do
		rows[key] = node
	end
	local face: Nodes = { rows = stack(rows, 8, 20) }
	return block(
		height,
		order,
		e(ToonSurface, {
			hue = "grape",
			pattern = "bubbles",
			radius = 24,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		})
	)
end

local function InventoryAboutColumns(props: InventoryCharacterPanelProps): (React.ReactNode, React.ReactNode)
	local layout = props.layout
	local phone = layout.phone
	local profile = EmployeeProfileRegistry.get(props.employee)
	if profile == nil then
		return nil, nil
	end
	local size = layout.textSize
	local words: Nodes = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, word in profile.words do
		words[`word{index}`] = e(ToonPill, {
			text = word,
			hue = "gold",
			textSize = size - 4,
			padX = 10,
			size = UDim2.fromOffset(math.floor(#word * (size - 4) * 0.62) + 30, size + 12),
			layoutOrder = index,
		})
	end
	local whoRows: Nodes = { bio = block(size * 4, 1, body(profile.bio, size, COLOR.white)) }
	if not phone then
		whoRows.words = block(size + 14, 2, group(words))
	end
	local who = aboutCard(`Who is {props.employee}?`, size, whoRows, size * 5 + (if phone then 30 else size + 60), 1)
	local fact = aboutCard("Fun fact", size, {
		fact = block(size * 3, 1, body(profile.funFact, size, COLOR.white)),
	}, size * 4 + 46, 2)
	local left = stack({ who = who, fact = fact }, layout.gap, 0)

	-- The ability card (its render breaking the left edge), the stat bars, the everyone line.
	local abilitySize = if phone then 70 else 120
	local ability: Nodes = {
		name = e(ToonText, {
			text = profile.ability.name,
			textSize = size + 12,
			position = UDim2.fromOffset(math.floor(abilitySize * 0.75), 10),
			size = UDim2.new(1, -math.floor(abilitySize * 0.75) - 100, 0, size + 16),
			fit = true,
		}),
		detail = e("Frame", {
			Position = UDim2.fromOffset(math.floor(abilitySize * 0.75), size + 30),
			Size = UDim2.new(1, -math.floor(abilitySize * 0.75) - 20, 1, -size - 40),
			BackgroundTransparency = 1,
		}, { text = body(if phone then profile.ability.line else profile.ability.detail, size - 2, COLOR.white) }),
		cooldown = e(ToonCooldown, {
			seconds = profile.ability.cooldown,
			height = if phone then 44 else 66,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -14, 0, 10),
			size = UDim2.fromOffset(if phone then 54 else 78, if phone then 44 else 66),
		}),
	}
	local row = if phone then 22 else 50
	local statsFace: Nodes = {
		rows = e(ToonStatRows, {
			rows = VM.stats(props.employee),
			row = row,
			barX = if phone then 104 else 200,
			textSize = size,
			position = UDim2.fromOffset(18, if phone then 10 else 22),
			size = UDim2.new(1, -36, 1, -(if phone then 20 else 44)),
		}),
	}
	local rightRows: Nodes = {
		ability = block(
			if phone then 84 else 150,
			1,
			group({
				card = e(ToonSurface, {
					hue = "grape",
					radius = 24,
					position = UDim2.fromOffset(math.floor(abilitySize * 0.3), 0),
					size = UDim2.new(1, -math.floor(abilitySize * 0.3), 1, -DEPTH.drop),
					children = ability,
				}),
				art = e(ToonIcon, {
					image = UIAssets.iconImage(profile.ability.icon),
					anchor = Vector2.new(0, 0.5),
					position = UDim2.new(0, -8, 0.5, -4),
					size = UDim2.fromOffset(abilitySize, abilitySize),
					drop = 4,
					zIndex = 3,
				}),
			})
		),
		stats = block(
			5 * row + (if phone then 24 else 48),
			2,
			e(ToonSurface, {
				hue = "grape",
				pattern = "bubbles",
				radius = 24,
				size = UDim2.new(1, 0, 1, -DEPTH.drop),
				children = statsFace,
			})
		),
	}
	if not phone then
		local everyone: Nodes = {
			text = e("Frame", {
				Position = UDim2.fromOffset(18, 10),
				Size = UDim2.new(1, -36, 1, -20),
				BackgroundTransparency = 1,
			}, {
				text = body(
					"Every employee can finish every job, even alone. Stats only change how it feels.",
					size - 2,
					COLOR.white
				),
			}),
		}
		rightRows.everyone = block(
			size * 3 + 20,
			3,
			e(ToonSurface, {
				hue = "night",
				radius = 20,
				size = UDim2.new(1, 0, 1, -DEPTH.drop),
				children = everyone,
			})
		)
	end
	return left, stack(rightRows, layout.gap, 0)
end

return InventoryAboutColumns
