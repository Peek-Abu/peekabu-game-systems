--!strict
--[=[
	InventoryCrewPanel: the Inventory's Crew tab (concept: characters/ui/character-ui/frames3/crew.jpg). A card per
	employee in their colour: a bright art window with rays and the employee in 3D in the skin they wear (a static
	ToonViewport), the skin's name on a ribbon over the window's top edge, "You!" on the one you play; under it the
	name, "Bunny · Crew speedster", the ability chip with its render, and the buttons for the card's state (Wearing +
	Skins, Equip + Skins, or locked: an interactive hire price + Look, with the night padlock on the art). Then the "???" card.
	The cards come from InventoryViewModel.crew; nothing here is per character. Presentational (exempt; story in
	InventoryScreen.story).

	@class InventoryCrewPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonGoo = require(Toon.ToonGoo)
local ToonIcon = require(Toon.ToonIcon)
local ToonPill = require(Toon.ToonPill)
local ToonPrice = require(Toon.ToonPrice)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.InventoryViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH
local RADIUS = 28

export type InventoryCrewPanelProps = {
	cards: { VM.CrewCard },
	layout: VM.Layout,
	onEquip: (employee: string) -> (),
	onHire: (employee: string) -> (),
	onOpen: (employee: string) -> (),
}

type Tint = { body: Color3, light: Color3, dark: Color3 }

-- The card's body: the employee's colour a step darker, so the bright art window stands out (the concept's footer).
local function bodyShade(color: Tint): UIToonConstants.Shade
	return { base = color.body:Lerp(color.dark, 0.3), hi = color.body, lo = color.dark }
end

-- The bright art window: the employee's light colour, rays, and whatever is passed in front.
local function window(color: Tint, size: Vector2, children: { [string]: React.ReactNode }): React.ReactNode
	local nodes: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, RADIUS - 8) }),
		stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }),
		gradient = e("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(color.light, color.body),
		}),
		rays = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(1.7, 1.7),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundTransparency = 1,
			Image = UIAssets.toon.rays,
			ImageColor3 = COLOR.white,
			ImageTransparency = 0.6,
			ZIndex = 1,
		}),
	}
	for key, node in children do
		nodes[key] = node
	end
	return e("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = COLOR.white,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
	}, nodes)
end

local function card(props: InventoryCrewPanelProps, entry: VM.CrewCard, order: number): React.ReactNode
	local layout = props.layout
	local phone = layout.phone
	local w, h = layout.crewCard.X, layout.crewCard.Y - DEPTH.drop - 12
	local artHeight = math.floor(h * 0.56)
	local nameSize = math.floor(h * 0.085)
	local lineSize = math.max(layout.textSize, math.floor(h * 0.032))
	local buttonHeight = math.max(40, math.floor(h * 0.085))
	local buttonText = if phone then 14 else math.max(18, math.floor(buttonHeight * 0.42))
	local locked = entry.state == "locked"
	local wearing = entry.state == "wearing"
	local pad = 18

	local art: { [string]: React.ReactNode } = {
		model = e(ToonViewport, {
			employee = entry.id,
			skin = entry.skinKey,
			framing = "full",
			dim = locked,
			position = UDim2.fromOffset(0, math.floor(artHeight * 0.06)),
			size = UDim2.new(1, 0, 1, -math.floor(artHeight * 0.04)),
			zIndex = 2,
		}),
	}
	if locked then
		local lock = math.floor(w * 0.3)
		-- Not hired yet: a price tag (you can hire them for Credits).
		art.lock = e(ToonIcon, {
			icon = "priceTag",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.62),
			size = UDim2.fromOffset(lock, lock),
			drop = 4,
			zIndex = 3,
		})
	end

	local face: { [string]: React.ReactNode } = {
		window = window(entry.color, Vector2.new(w - 20, artHeight), art),
		name = e(ToonText, {
			text = string.upper(entry.name),
			textSize = nameSize,
			position = UDim2.fromOffset(pad, artHeight + 22),
			size = UDim2.fromOffset(w - 2 * pad, nameSize + 8),
			fit = true,
			zIndex = 3,
		}),
		-- No room for the line between the name and the buttons on a phone card.
		line = if phone
			then nil
			else e(ToonText, {
				text = `{entry.kind} · {entry.line}`,
				font = "body",
				color = COLOR.white,
				textSize = lineSize,
				position = UDim2.fromOffset(pad, artHeight + 30 + nameSize),
				size = UDim2.fromOffset(w - 2 * pad, lineSize + 6),
				fit = true,
				zIndex = 3,
			}),
	}
	-- The ability chip, its render breaking the chip's left end (no room on a phone card).
	if not phone then
		local chipHeight = math.floor(lineSize * 1.6)
		local chipY = artHeight + 44 + nameSize + lineSize
		face.ability = e(ToonPill, {
			text = entry.ability,
			hue = "night",
			textSize = lineSize,
			padX = 8,
			position = UDim2.fromOffset(pad + math.floor(chipHeight * 0.9), chipY),
			size = UDim2.fromOffset(math.min(w - 2 * pad - chipHeight, math.floor(w * 0.55)), chipHeight),
			zIndex = 3,
		})
		face.abilityArt = e(ToonIcon, {
			image = entry.abilityImage,
			anchor = Vector2.new(0, 0.5),
			position = UDim2.fromOffset(pad - 6, chipY + math.floor(chipHeight / 2)),
			size = UDim2.fromOffset(math.floor(chipHeight * 1.5), math.floor(chipHeight * 1.5)),
			drop = 3,
			zIndex = 4,
		})
	end

	local buttonY = h - buttonHeight - DEPTH.lip - 14
	local half = math.floor((w - 2 * pad - 10) / 2)
	if locked then
		local price: { [string]: React.ReactNode } = {
			price = e(ToonPrice, {
				currency = "credits",
				amount = entry.priceText or "",
				textSize = math.floor(buttonHeight * 0.48),
				meaning = "white",
				align = "center",
				size = UDim2.new(1, 0, 1, -4),
			}),
		}
		face.price = e(ToonButton, {
			variant = "gleam",
			content = price,
			onActivated = function()
				props.onHire(entry.id)
			end,
			radius = 999,
			small = true,
			position = UDim2.fromOffset(pad, buttonY),
			size = UDim2.fromOffset(half + 16, buttonHeight),
			zIndex = 3,
		})
		face.look = e(ToonButton, {
			variant = "night",
			text = "Look",
			textSize = buttonText,
			position = UDim2.fromOffset(pad + half + 26, buttonY),
			size = UDim2.fromOffset(half - 16, buttonHeight),
			onActivated = function()
				props.onOpen(entry.id)
			end,
			zIndex = 3,
		})
	else
		face.equip = e(ToonButton, {
			variant = if wearing then "secondary" else "primary",
			text = if wearing then "Wearing" else "Equip",
			textSize = buttonText,
			disabled = wearing,
			position = UDim2.fromOffset(pad, buttonY),
			size = UDim2.fromOffset(half + 16, buttonHeight),
			onActivated = function()
				props.onEquip(entry.id)
			end,
			zIndex = 3,
		})
		face.skins = e(ToonButton, {
			variant = "grape",
			text = "Skins",
			textSize = buttonText,
			position = UDim2.fromOffset(pad + half + 26, buttonY),
			size = UDim2.fromOffset(half - 16, buttonHeight),
			onActivated = function()
				props.onOpen(entry.id)
			end,
			zIndex = 3,
		})
	end

	local flagHeight = if phone then 26 else 40
	return e("Frame", {
		Size = UDim2.fromOffset(w, h + DEPTH.drop + 12),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		ring = if wearing
			then e("Frame", {
				Position = UDim2.fromOffset(-8, 4),
				Size = UDim2.fromOffset(w + 16, h + DEPTH.drop + 16),
				BackgroundTransparency = 1,
				ZIndex = 1,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, RADIUS + 8) }),
				stroke = e("UIStroke", { Color = COLOR.selected, Thickness = 6 }),
			})
			else nil,
		surface = e(ToonSurface, {
			hue = "grape",
			shade = bodyShade(entry.color),
			radius = RADIUS,
			gloss = false,
			position = UDim2.fromOffset(0, 12),
			size = UDim2.fromOffset(w, h),
			zIndex = 2,
			children = face,
		}),
		flag = if entry.skinName ~= ""
			then e(ToonFlag, {
				text = entry.skinName,
				hue = "night",
				tilt = -2,
				textSize = if phone then 13 else 20,
				anchor = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, 4),
				size = UDim2.fromOffset(math.floor(w * 0.6), flagHeight),
				zIndex = 5,
			})
			else nil,
		you = if wearing
			then e(ToonFlag, {
				text = "You!",
				hue = "mint",
				tilt = 10,
				textSize = if phone then 14 else 24,
				anchor = Vector2.new(1, 0),
				position = UDim2.new(1, 14, 0, 0),
				size = UDim2.fromOffset(if phone then 62 else 100, flagHeight + 4),
				zIndex = 6,
			})
			else nil,
	})
end

-- The card for whoever is hired next: a dark card, a bunny silhouette in the window, goo dripping off the top.
local function nextCard(layout: VM.Layout, order: number): React.ReactNode
	local w, h = layout.crewCard.X, layout.crewCard.Y - DEPTH.drop - 12
	local artHeight = math.floor(h * 0.56)
	local nameSize = math.floor(h * 0.085)
	local lineSize = math.max(layout.textSize, math.floor(h * 0.032))
	local night = UIToonConstants.shade("night")
	local art: { [string]: React.ReactNode } = {
		-- A dark silhouette of a bunny (an employee render tinted to a shadow): someone is coming, not who.
		silhouette = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1.04),
			Size = UDim2.fromScale(0.95, 0.95),
			BackgroundTransparency = 1,
			Image = UIAssets.iconImage("pippaHappy") or "",
			ImageColor3 = night.lo,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}),
	}
	local face: { [string]: React.ReactNode } = {
		window = window({ body = night.base, light = night.hi, dark = night.lo }, Vector2.new(w - 20, artHeight), art),
		goo = e(ToonGoo, { kind = "cap", width = w, radius = RADIUS, scale = 0.7, zIndex = 4 }),
		mark = e(ToonText, {
			text = "???",
			textSize = nameSize,
			position = UDim2.fromOffset(18, artHeight + 22),
			size = UDim2.fromOffset(w - 36, nameSize + 8),
			fit = true,
			zIndex = 3,
		}),
		soon = e(ToonText, {
			text = "A new face joins soon",
			font = "body",
			color = COLOR.white,
			textSize = lineSize,
			position = UDim2.fromOffset(18, artHeight + 30 + nameSize),
			size = UDim2.fromOffset(w - 36, lineSize + 6),
			fit = true,
			zIndex = 3,
		}),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(w, h + DEPTH.drop + 12),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		surface = e(ToonSurface, {
			hue = "night",
			radius = RADIUS,
			gloss = false,
			position = UDim2.fromOffset(0, 12),
			size = UDim2.fromOffset(w, h),
			children = face,
		}),
	})
end

local function InventoryCrewPanel(props: InventoryCrewPanelProps): React.ReactNode
	local layout = props.layout
	-- Centred when the cards fit; from the left (scrolling) when they do not, so none is cut on both sides.
	local count = #props.cards + 1
	local spacing = layout.gap + (if layout.phone then 8 else 26)
	local total = count * layout.crewCard.X + (count - 1) * spacing + 40
	local rows: { [string]: React.ReactNode } = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if total <= layout.content.width
				then Enum.HorizontalAlignment.Center
				else Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, spacing),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		-- Room for the tilted flags that stick out over the cards' top corners.
		pad = e("UIPadding", {
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
			PaddingTop = UDim.new(0, layout.crewPad.top),
			PaddingBottom = UDim.new(0, layout.crewPad.bottom - 6),
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
		-- The bar sits under the cards, never over their feet.
		HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	}, rows)
end

return InventoryCrewPanel
