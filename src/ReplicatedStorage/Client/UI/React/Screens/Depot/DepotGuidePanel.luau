--!strict
--[=[
	DepotGuidePanel: the GUIDE page's body in the V1 kit (p075 scene menus, owner yes 2026-11-14): the HOW TO PLAY |
	MONSTERS tabs over either
	- four step cards in a row, each in its own colour: a gold number breaking its corner, a real posed in-game photo
	  in an ink frame, the step's name and one short line (the vacuum step adds the player's live control; the way back
	  into training sits under the cards when the hub has a Training pad), or
	- three monster cards: the monster's cut-out breaking out of the top of his graded photo, his place on a pill, his
	  name on a tilted night band and his lore on a cream plate; the coming-soon card is the same size, dark, with the
	  kit's Gloom goo dripping from its top, a big "?" and COMING SOON caution tape.
	Laid out in the sheet's design px (desktop, phone); presentational, the words are DepotGuideViewModel.

	@class DepotGuidePanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local VM = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotGuideViewModel)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonGoo = require(Toon.ToonGoo)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

type Nodes = { [string]: React.ReactNode }

local INK = UIToonConstants.COLOR.ink
local WHITE = Color3.new(1, 1, 1)

export type DepotGuidePanelProps = {
	tab: VM.Tab,
	phone: boolean,
	-- The body's size inside the sheet, design px.
	width: number,
	height: number,
	onTab: (tab: VM.Tab) -> (),
	-- The player's live vacuum control, shown under the vacuum step.
	control: string?,
	-- The way back into training (nil where the hub has no Training pad).
	training: { text: string, onActivated: () -> () }?,
}

-- A typed child table (an inline literal would be read as one exact element type, not the kit's node map).
local function kids(nodes: Nodes): Nodes
	return nodes
end

local function custom(colour: Color3): UIToonConstants.Shade
	return { base = colour, hi = colour:Lerp(WHITE, 0.45), lo = colour:Lerp(Color3.new(0, 0, 0), 0.35) }
end

local function photo(
	id: string,
	position: UDim2,
	size: UDim2,
	stroke: number,
	radius: number,
	zIndex: number,
	children: Nodes?
): React.ReactNode
	local nodes: Nodes = {
		corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
		stroke = e("UIStroke", { Color = INK, Thickness = stroke }),
	}
	if children ~= nil then
		for key, node in children do
			nodes[key] = node
		end
	end
	return e("ImageLabel", {
		Position = position,
		Size = size,
		BackgroundColor3 = UIToonConstants.shade("night").lo,
		Image = id,
		ScaleType = Enum.ScaleType.Crop,
		ClipsDescendants = true,
		ZIndex = zIndex,
	}, nodes)
end

local function stepCards(props: DepotGuidePanelProps, top: number, height: number): Nodes
	local phone = props.phone
	local gap = if phone then 10 else 24
	local width = (props.width - 3 * gap) / 4
	local inset = if phone then 6 else 14
	local photoHeight = math.min(width * 1.2, height * 0.62)
	local titleSize = if phone then 15 else 34
	local lineSize = if phone then 12 else 24
	local numberSize = if phone then 34 else 76
	local nodes: Nodes = {}
	for index, step in VM.steps(props.control) do
		local x = (index - 1) * (width + gap)
		local cardTop = top + numberSize * 0.3
		local cardHeight = height - numberSize * 0.3
		nodes[`step{index}`] = e(ToonSurface, {
			hue = step.hue,
			position = UDim2.fromOffset(x, cardTop),
			size = UDim2.fromOffset(width, cardHeight),
			radius = if phone then 12 else 22,
			pattern = "bubbles",
			small = phone,
			zIndex = 2,
		})
		nodes[`stepPhoto{index}`] = photo(
			step.photo,
			UDim2.fromOffset(x + inset, cardTop + inset),
			UDim2.fromOffset(width - 2 * inset, photoHeight),
			if phone then 3 else 5,
			if phone then 8 else 16,
			3
		)
		nodes[`stepNumber{index}`] = e(ToonSurface, {
			hue = "gold",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromOffset(x + numberSize * 0.36, cardTop + numberSize * 0.1),
			size = UDim2.fromOffset(numberSize, numberSize),
			radius = math.floor(numberSize / 2),
			small = phone,
			zIndex = 5,
			children = kids({
				number = e(ToonText, {
					text = tostring(step.number),
					textSize = math.floor(numberSize * 0.62),
					align = "center",
					alignY = "center",
					size = UDim2.fromScale(1, 1),
					zIndex = 6,
				}),
			}),
		})
		local textTop = cardTop + inset + photoHeight + (if phone then 6 else 22)
		nodes[`stepTitle{index}`] = e(ToonText, {
			text = step.title,
			textSize = titleSize,
			align = "center",
			position = UDim2.fromOffset(x + inset, textTop),
			size = UDim2.fromOffset(width - 2 * inset, titleSize + 6),
			fit = true,
			zIndex = 4,
		})
		nodes[`stepLine{index}`] = e(ToonText, {
			text = step.line,
			font = "body",
			textSize = lineSize,
			color = if step.hue == "sky" or step.hue == "mint" then INK else WHITE,
			align = "center",
			alignY = "top",
			wrapped = true,
			position = UDim2.fromOffset(x + inset, textTop + titleSize + (if phone then 4 else 14)),
			size = UDim2.fromOffset(width - 2 * inset, lineSize * 2 + 10),
			zIndex = 4,
		})
		local hint = step.hint
		if hint ~= nil then
			nodes[`stepHint{index}`] = e(ToonText, {
				text = hint,
				font = "body",
				textSize = if phone then 12 else 18,
				color = UIToonConstants.shade("grape").hi,
				align = "center",
				alignY = "top",
				wrapped = true,
				fit = true,
				position = UDim2.fromOffset(x + inset, textTop + titleSize + lineSize * 2 + (if phone then 14 else 34)),
				size = UDim2.fromOffset(width - 2 * inset, (if phone then 12 else 18) * 2 + 6),
				zIndex = 4,
			})
		end
	end
	return nodes
end

local function tape(width: number, height: number, phone: boolean): React.ReactNode
	local stripes: Nodes = {
		label = e(ToonText, {
			text = "COMING SOON",
			textSize = if phone then 13 else 28,
			align = "center",
			alignY = "center",
			size = UDim2.fromScale(1, 1),
			zIndex = 9,
		}),
	}
	local band = if phone then 12 else 26
	for index = 0, math.ceil(width * 1.4 / (band * 2)) do
		stripes[`stripe{index}`] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(index * band * 2, height / 2),
			Size = UDim2.fromOffset(band, height * 2.2),
			Rotation = 45,
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			ZIndex = 8,
		})
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(width * 1.25, height),
		Rotation = -8,
		BackgroundColor3 = UIToonConstants.shade("gold").base,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 7,
	}, stripes)
end

local function monsterCards(props: DepotGuidePanelProps, top: number, height: number): Nodes
	local phone = props.phone
	local gap = if phone then 12 else 28
	local width = (props.width - 2 * gap) / 3
	local inset = if phone then 6 else 18
	local photoHeight = height * 0.56
	local nameSize = if phone then 18 else 56
	local loreSize = if phone then 12 else 27
	local nodes: Nodes = {}
	for index, monster in VM.monsters() do
		local x = (index - 1) * (width + gap)
		local cardTop = top + (if phone then 18 else 50)
		local cardHeight = height - (if phone then 18 else 50)
		nodes[`card{index}`] = e(ToonSurface, {
			hue = monster.hue,
			shade = if monster.colour ~= nil then custom(monster.colour) else nil,
			position = UDim2.fromOffset(x, cardTop),
			size = UDim2.fromOffset(width, cardHeight),
			radius = if phone then 12 else 22,
			small = phone,
			zIndex = 2,
		})
		local inner: Nodes = {}
		if monster.soon then
			inner.dark = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = INK,
				BackgroundTransparency = 0.45,
				ZIndex = 4,
			})
			inner.goo = e(ToonGoo, {
				kind = "cap",
				width = width - 2 * inset,
				radius = if phone then 8 else 16,
				scale = if phone then 0.5 else 1,
				zIndex = 6,
			})
			inner.mark = e(ToonText, {
				text = "?",
				textSize = math.floor(photoHeight * 0.55),
				color = UIToonConstants.shade("grape").hi,
				align = "center",
				alignY = "center",
				size = UDim2.fromScale(1, 1),
				zIndex = 6,
			})
			inner.tape = tape(width - 2 * inset, if phone then 22 else 46, phone)
		end
		nodes[`photo{index}`] = photo(
			monster.photo,
			UDim2.fromOffset(x + inset, cardTop + inset),
			UDim2.fromOffset(width - 2 * inset, photoHeight),
			if phone then 3 else 5,
			if phone then 8 else 18,
			3,
			inner
		)
		local cut = monster.cut
		if cut ~= nil then
			-- The cut-out stands on the photo's foot and breaks out of its top.
			nodes[`cut{index}`] = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromOffset(x + width / 2, cardTop + inset + photoHeight),
				Size = UDim2.fromOffset(width * 0.86, photoHeight * 1.2),
				BackgroundTransparency = 1,
				Image = cut,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 5,
			})
		end
		nodes[`place{index}`] = e(ToonPill, {
			text = monster.place,
			hue = if monster.soon then "lilac" else "cream",
			textSize = if phone then 11 else 20,
			position = UDim2.fromOffset(x + inset * 2, cardTop + inset * 2),
			size = UDim2.fromOffset(if phone then 82 else 170, if phone then 20 else 38),
			zIndex = 7,
		})
		local bandWidth = math.min(width * 0.86, (#monster.name + 1.5) * nameSize * 0.56)
		local bandY = cardTop + inset + photoHeight - nameSize * 0.55
		nodes[`band{index}`] = e(ToonSurface, {
			hue = if monster.soon then "grape" else "night",
			position = UDim2.fromOffset(x - (if phone then 4 else 12), bandY),
			size = UDim2.fromOffset(bandWidth, nameSize * 1.5),
			radius = if phone then 8 else 18,
			small = phone,
			zIndex = 8,
			children = kids({
				name = e(ToonText, {
					text = monster.name,
					textSize = nameSize,
					color = monster.nameColour,
					align = "center",
					alignY = "center",
					fit = true,
					size = UDim2.fromScale(1, 1),
					zIndex = 9,
				}),
			}),
		})
		local plateTop = bandY + nameSize * 1.5 + (if phone then 6 else 18)
		nodes[`lore{index}`] = e(ToonSurface, {
			hue = "cream",
			pattern = "rings",
			position = UDim2.fromOffset(x + inset * 1.3, plateTop),
			size = UDim2.fromOffset(width - inset * 2.6, cardTop + cardHeight - plateTop - inset * 1.4),
			radius = if phone then 8 else 18,
			small = phone,
			zIndex = 4,
			children = kids({
				text = e(ToonText, {
					text = table.concat(monster.lore, "\n"),
					font = "body",
					textSize = loreSize,
					color = INK,
					align = "center",
					alignY = "center",
					wrapped = true,
					fit = true,
					position = UDim2.fromScale(0.04, 0.06),
					size = UDim2.fromScale(0.92, 0.82),
					zIndex = 5,
				}),
			}),
		})
	end
	return nodes
end

local function DepotGuidePanel(props: DepotGuidePanelProps): React.ReactNode
	local phone = props.phone
	local tabHeight = if phone then 34 else 64
	local tabWidth = if phone then 150 else 290
	local nodes: Nodes = {}
	for index, tab in VM.tabs(props.tab) do
		nodes[`tab{index}`] = e(ToonButton, {
			variant = if tab.selected then "grape" else "secondary",
			text = tab.label,
			textSize = if phone then 15 else 28,
			selected = tab.selected,
			position = UDim2.fromOffset((index - 1) * (tabWidth + (if phone then 10 else 24)), 0),
			size = UDim2.fromOffset(tabWidth, tabHeight),
			sound = "click",
			onActivated = function()
				props.onTab(tab.tab)
			end,
		})
	end
	local top = tabHeight + (if phone then 10 else 26)
	local trainingHeight = if props.training ~= nil and props.tab == "play" then (if phone then 40 else 72) else 0
	local height = props.height - top - trainingHeight
	local cards = if props.tab == "play" then stepCards(props, top, height) else monsterCards(props, top, height)
	for key, node in cards do
		nodes[key] = node
	end
	local training = props.training
	if training ~= nil and props.tab == "play" then
		nodes.training = e(ToonButton, {
			variant = "gleam",
			text = training.text,
			textSize = if phone then 15 else 24,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.fromScale(0.5, 1),
			size = UDim2.fromOffset(if phone then 220 else 360, trainingHeight - (if phone then 6 else 10)),
			sound = "confirm",
			onActivated = training.onActivated,
		})
	end
	return e("Frame", {
		Size = UDim2.fromOffset(props.width, props.height),
		BackgroundTransparency = 1,
	}, nodes)
end

return DepotGuidePanel
