--!strict
--[=[
	ShopPassesPanel: the Shop's Passes tab. PASSES over a plain promise ("Yours forever. Passes never make you
	stronger."), then a card per game pass (ShopViewModel.passes): a grape surface with the pass's own Roblox icon
	breaking its left edge (the crew crown until Roblox has answered), its name, its line, and the button: the Robux
	price, greyed "..." while it loads, "Soon" off sale, a gold "Owned" once bought. `onBuy` opens Roblox's purchase
	prompt; the button is only live for "buy". Presentational (exempt; story in ShopPassesPanel.story).

	@class ShopPassesPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.ShopViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

export type ShopPassesPanelProps = {
	cards: { VM.PassCard },
	width: number,
	height: number,
	headingSize: number,
	textSize: number,
	phone: boolean,
	onBuy: (key: string) -> (),
}

local function card(view: VM.PassCard, size: Vector2, phone: boolean, order: number, onBuy: (string) -> ())
	local art = math.floor(size.Y * 0.95)
	local nameSize = if phone then 20 else 40
	local lineSize = if phone then 13 else 22
	local buttonSize = Vector2.new(if phone then 110 else 200, if phone then 34 else 56)
	local textLeft = art + (if phone then 4 else 12)
	local textWidth = size.X - textLeft - buttonSize.X - 32
	local buyable = view.state == "buy"
	local face: { [string]: React.ReactNode } = {
		name = e(ToonText, {
			text = view.name,
			textSize = nameSize,
			meaning = "white",
			position = UDim2.fromOffset(textLeft, if phone then 8 else 18),
			size = UDim2.fromOffset(textWidth, nameSize + 6),
			fit = true,
		}),
		line = e(ToonText, {
			text = view.line,
			font = "body",
			textSize = lineSize,
			color = COLOR.white,
			position = UDim2.fromOffset(textLeft, (if phone then 8 else 18) + nameSize + 8),
			size = UDim2.fromOffset(textWidth, lineSize * 2 + 6),
			wrapped = true,
			fit = true,
		}),
		buy = e(ToonButton, {
			variant = if view.state == "owned" then "gleam" elseif buyable then "primary" else "secondary",
			text = view.button,
			textSize = if phone then 16 else 28,
			disabled = not buyable and view.state ~= "owned",
			selected = view.state == "owned",
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -16, 0.5, -DEPTH.lip / 2),
			size = UDim2.fromOffset(buttonSize.X, buttonSize.Y),
			sound = "cta",
			onActivated = function()
				if buyable then
					onBuy(view.key)
				end
			end,
		}),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		surface = e(ToonSurface, {
			hue = "grape",
			radius = 22,
			small = phone,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		}),
		-- The pass's own icon breaks the card's left edge (the crown until Roblox has answered).
		icon = e(ToonIcon, {
			icon = if view.icon == nil then "hostCrown" else nil,
			image = view.icon,
			anchor = Vector2.new(0, 0.5),
			position = UDim2.new(0, -art * 0.12, 0.5, -DEPTH.drop),
			size = UDim2.fromOffset(art, art),
			drop = 5,
			greyed = view.state == "loading",
			zIndex = 4,
		}),
	})
end

local function ShopPassesPanel(props: ShopPassesPanelProps): React.ReactNode
	local gap = if props.phone then 10 else 18
	local top = props.headingSize + props.textSize * 2 + 30
	local cardHeight = if props.phone then 96 else 170
	local cardWidth = math.min(props.width - 24, if props.phone then 620 else 1100)
	local list: { [string]: React.ReactNode } = {
		layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		pad = e("UIPadding", { PaddingTop = UDim.new(0, 18), PaddingLeft = UDim.new(0, 24) }),
	}
	for index, view in props.cards do
		list[view.key] = card(view, Vector2.new(cardWidth, cardHeight), props.phone, index, props.onBuy)
	end
	return e("Frame", {
		Size = UDim2.fromOffset(props.width, props.height),
		BackgroundTransparency = 1,
	}, {
		heading = e(ToonText, {
			text = "PASSES",
			textSize = props.headingSize,
			position = UDim2.fromOffset(0, 0),
			size = UDim2.fromOffset(600, props.headingSize + 8),
			fit = true,
		}),
		note = e(ToonText, {
			text = "Yours forever. Passes never make you stronger.",
			font = "body",
			color = COLOR.white,
			textSize = props.textSize,
			position = UDim2.fromOffset(0, props.headingSize + 12),
			size = UDim2.new(1, 0, 0, props.textSize * 2 + 6),
			wrapped = true,
			fit = true,
		}),
		cards = e("ScrollingFrame", {
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.new(1, 0, 1, -top),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
		}, list),
	})
end

return ShopPassesPanel
