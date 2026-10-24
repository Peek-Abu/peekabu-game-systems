--!strict
--[=[
	InventoryCrewPanel: the Inventory's Crew tab: a card per employee in their colour, showing them in 3D in the skin
	they wear (a static ToonViewport), its name on a flag, their name, line and ability, and the buttons for their
	state (Wearing + Skins, Equip + Skins, or locked: the hire price + Look). Then a "???" card for whoever is next.
	The cards come from InventoryViewModel.crew; nothing here is per character. Presentational (exempt; story in
	InventoryScreen.story).

	@class InventoryCrewPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonGoo = require(Toon.ToonGoo)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

export type InventoryCrewPanelProps = {
	cards: { VM.CrewCard },
	layout: VM.Layout,
	onEquip: (employee: string) -> (),
	onOpen: (employee: string) -> (),
}

local function shadeOf(color: { body: Color3, light: Color3, dark: Color3 }): UIToonConstants.Shade
	return { base = color.body, hi = color.light, lo = color.dark }
end

local function card(props: InventoryCrewPanelProps, entry: VM.CrewCard, order: number): React.ReactNode
	local size = props.layout.crewCard
	local phone = props.layout.phone
	local w, h = size.X, size.Y
	local artHeight = math.floor(h * 0.56)
	local buttonHeight = if phone then 40 else 58
	local buttonText = if phone then 16 else 22
	local locked = entry.state == "locked"
	local face: { [string]: React.ReactNode } = {
		art = e(ToonViewport, {
			employee = entry.id,
			skin = entry.skinKey,
			framing = "full",
			dim = locked,
			position = UDim2.fromOffset(6, 6),
			size = UDim2.fromOffset(w - 12, artHeight),
			zIndex = 2,
		}),
		name = e(ToonText, {
			text = string.upper(entry.name),
			textSize = props.layout.headingSize,
			position = UDim2.fromOffset(14, artHeight + 6),
			size = UDim2.fromOffset(w - 28, props.layout.headingSize + 6),
			fit = true,
			zIndex = 3,
		}),
		line = e(ToonText, {
			text = entry.line,
			font = "body",
			color = UIToonConstants.COLOR.white,
			textSize = props.layout.textSize,
			position = UDim2.fromOffset(14, artHeight + props.layout.headingSize + 12),
			size = UDim2.fromOffset(w - 28, props.layout.textSize + 6),
			fit = true,
			zIndex = 3,
		}),
		ability = e(ToonPill, {
			text = entry.ability,
			hue = "night",
			textSize = props.layout.textSize - 2,
			position = UDim2.fromOffset(14, artHeight + props.layout.headingSize + props.layout.textSize + 24),
			size = UDim2.fromOffset(math.min(w - 28, if phone then 130 else 200), props.layout.textSize + 16),
			zIndex = 3,
		}),
	}
	local buttonY = h - buttonHeight - 22
	local half = math.floor((w - 28 - 8) / 2)
	if locked then
		face.price = e(ToonPill, {
			text = entry.priceText or "",
			meaning = "gold",
			icon = "credits",
			textSize = buttonText,
			position = UDim2.fromOffset(14, buttonY),
			size = UDim2.fromOffset(half, buttonHeight),
			zIndex = 3,
		})
		face.look = e(ToonButton, {
			variant = "secondary",
			text = "Look",
			textSize = buttonText,
			position = UDim2.fromOffset(14 + half + 8, buttonY),
			size = UDim2.fromOffset(half, buttonHeight),
			onActivated = function()
				props.onOpen(entry.id)
			end,
			zIndex = 3,
		})
	else
		local wearing = entry.state == "wearing"
		face.equip = e(ToonButton, {
			variant = if wearing then "secondary" else "primary",
			text = if wearing then "Wearing" else "Equip",
			textSize = buttonText,
			disabled = wearing,
			position = UDim2.fromOffset(14, buttonY),
			size = UDim2.fromOffset(half, buttonHeight),
			onActivated = function()
				props.onEquip(entry.id)
			end,
			zIndex = 3,
		})
		face.skins = e(ToonButton, {
			variant = "grape",
			text = "Skins",
			textSize = buttonText,
			position = UDim2.fromOffset(14 + half + 8, buttonY),
			size = UDim2.fromOffset(half, buttonHeight),
			onActivated = function()
				props.onOpen(entry.id)
			end,
			zIndex = 3,
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		surface = e(ToonSurface, {
			hue = "grape",
			shade = shadeOf(entry.color),
			radius = 24,
			size = UDim2.new(1, 0, 1, -UIToonConstants.DEPTH.drop),
			children = face,
		}),
		flag = if entry.skinName ~= ""
			then e(ToonFlag, {
				text = entry.skinName,
				hue = if locked then "steel" else "night",
				textSize = if phone then 14 else 18,
				position = UDim2.fromOffset(-6, 10),
				size = UDim2.fromOffset(math.min(w - 20, if phone then 120 else 180), if phone then 28 else 36),
				zIndex = 5,
			})
			else nil,
	})
end

-- The card for whoever is hired next: a dark card with a "???" and goo dripping off its top.
local function nextCard(layout: VM.Layout, order: number): React.ReactNode
	local size = layout.crewCard
	local face: { [string]: React.ReactNode } = {
		mark = e(ToonText, {
			text = "???",
			textSize = if layout.phone then 64 else 110,
			meaning = "grape",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.42),
			size = UDim2.new(1, -20, 0, if layout.phone then 72 else 120),
			align = "center",
		}),
		soon = e(ToonText, {
			text = "Coming soon",
			textSize = layout.headingSize - 6,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.fromScale(0.5, 0.62),
			size = UDim2.new(1, -20, 0, layout.headingSize),
			align = "center",
			fit = true,
		}),
		goo = e(ToonGoo, { kind = "cap", width = size.X, radius = 24, scale = 0.6 }),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		surface = e(ToonSurface, {
			hue = "night",
			radius = 24,
			size = UDim2.new(1, 0, 1, -UIToonConstants.DEPTH.drop),
			children = face,
		}),
	})
end

local function InventoryCrewPanel(props: InventoryCrewPanelProps): React.ReactNode
	local layout = props.layout
	local rows: { [string]: React.ReactNode } = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, layout.gap + 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	}
	for index, entry in props.cards do
		rows[entry.id] = card(props, entry, index)
	end
	rows.next = nextCard(layout, #props.cards + 1)
	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UIToonConstants.shade("lilac").base,
	}, rows)
end

return InventoryCrewPanel
