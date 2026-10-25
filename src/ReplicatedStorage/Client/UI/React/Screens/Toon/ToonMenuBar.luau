--!strict
--[=[
	ToonMenuBar: the top bar every full-screen character menu shares (Inventory, an employee's page, the Shop):
	- left: a back button (optional), then the title plate on the kit's stack with its render breaking the plate's
	  left edge (an icon, or `art`: a node drawn in the icon's place, like an employee's head);
	- the tabs: inline buttons with small renders, the current one selected, greyed ones with a "Soon" ribbon above;
	- right: the Credits and Gleam wallets (render overlapping a gold number) and the coral close.
	Sizes come from the caller's layout (design px, inside PaperHudFrame). Presentational (exempt; story in
	ToonMenuBar.story).

	@class ToonMenuBar
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonPill = require(Toon.ToonPill)
local ToonStyleViewModel = require(Toon.ToonStyleViewModel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

export type Tab = {
	id: string,
	text: string,
	icon: UIAssets.ToonIcon?,
	-- Greyed with a "Soon" ribbon (not built yet).
	soon: boolean?,
}

export type ToonMenuBarProps = {
	title: string,
	icon: UIAssets.ToonIcon?,
	-- Drawn in the icon's place (given its size in px).
	art: ((size: number) -> React.ReactNode)?,
	-- The title plate's hue (default grape).
	hue: UIToonConstants.Hue?,
	tabs: { Tab },
	current: string?,
	onTab: (id: string) -> (),
	back: { text: string, onActivated: () -> () }?,
	credits: number,
	gleam: number,
	onClose: () -> (),
	-- Layout (design px).
	x: number,
	height: number,
	phone: boolean,
}

local function ToonMenuBar(props: ToonMenuBarProps): React.ReactNode
	local h = props.height
	local phone = props.phone
	local nodes: { [string]: React.ReactNode } = {}
	local x = props.x

	local back = props.back
	if back ~= nil then
		local width = if phone then 96 else 150
		nodes.back = e(ToonButton, {
			variant = "danger",
			text = back.text,
			textSize = math.floor(h * 0.38),
			sound = "back",
			position = UDim2.fromOffset(x, 4),
			size = UDim2.fromOffset(width, h - 8),
			onActivated = back.onActivated,
		})
		x += width + 14
	end

	-- The title plate: the render breaks its left edge and top.
	local titleSize = math.floor(h * 0.66)
	local art = math.floor(h * 1.45)
	local plateWidth = math.floor(#props.title * titleSize * 0.62) + art * 0.62 + 30
	local plateFace: { [string]: React.ReactNode } = {
		title = e(ToonText, {
			text = props.title,
			textSize = titleSize,
			position = UDim2.fromOffset(math.floor(art * 0.62), -2),
			size = UDim2.new(1, -math.floor(art * 0.62) - 14, 1, -UIToonConstants.DEPTH.lip),
			fit = true,
			zIndex = 3,
		}),
	}
	nodes.plate = e(ToonSurface, {
		hue = props.hue or "grape",
		radius = 22,
		position = UDim2.fromOffset(x + math.floor(art * 0.3), 2),
		size = UDim2.fromOffset(plateWidth, h - 4),
		children = plateFace,
		zIndex = 2,
	})
	local artNode: React.ReactNode = nil
	if props.art ~= nil then
		artNode = props.art(art)
	elseif props.icon ~= nil then
		artNode = e(ToonIcon, {
			icon = props.icon,
			size = UDim2.fromOffset(art, art),
			drop = 5,
		})
	end
	if artNode ~= nil then
		nodes.art = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(x, math.floor(h * 0.46)),
			Size = UDim2.fromOffset(art, art),
			Rotation = -6,
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, { node = artNode })
	end
	x += math.floor(art * 0.3) + plateWidth + (if phone then 14 else 24)

	-- The tabs.
	local tabText = math.floor(h * 0.4)
	for index, tab in props.tabs do
		local width = math.floor(#tab.text * tabText * 0.66) + (if tab.icon ~= nil then tabText * 2 + 14 else 34)
		local selected = tab.id == props.current
		local soon = tab.soon == true
		nodes[`tab{index}`] = e(ToonButton, {
			variant = if soon then "secondary" else if selected then "gleam" else "grape",
			text = tab.text,
			icon = tab.icon,
			textSize = tabText,
			disabled = soon,
			selected = selected,
			position = UDim2.fromOffset(x, 6),
			size = UDim2.fromOffset(width, h - 14),
			onActivated = function()
				if not soon then
					props.onTab(tab.id)
				end
			end,
		})
		if soon then
			-- Over the tab's top-right corner, kept inside the bar (the screen's edge would cut a flag above it),
			-- and wide enough for the whole word next to the notch.
			local flagText = if phone then 13 else 16
			nodes[`soon{index}`] = e(ToonFlag, {
				text = "Soon",
				hue = "coral",
				tilt = 6,
				textSize = flagText,
				anchor = Vector2.new(1, 0),
				position = UDim2.fromOffset(x + width + 16, -8),
				size = UDim2.fromOffset(math.floor(4 * flagText * 0.75) + 44, if phone then 22 else 28),
				zIndex = 5,
			})
		end
		x += width + (if phone then 8 else 12)
	end

	-- The wallets and the close, from the right.
	local walletText = math.floor(h * 0.44)
	local walletWidth = if phone then 120 else 190
	nodes.close = e(ToonButton, {
		variant = "danger",
		text = "X",
		textSize = math.floor(h * 0.5),
		sound = "back",
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -12, 0, 2),
		size = UDim2.fromOffset(h, h - 4),
		onActivated = props.onClose,
	})
	for index, wallet in
		{
			{ id = "gleam", amount = props.gleam },
			{ id = "credits", amount = props.credits },
		}
	do
		local icon: UIAssets.ToonIcon = if wallet.id == "gleam" then "gleam" else "credits"
		nodes[wallet.id] = e(ToonPill, {
			text = ToonStyleViewModel.grouped(wallet.amount),
			meaning = "gold",
			icon = icon,
			textSize = walletText,
			iconSize = math.floor(h * 1.05),
			small = false,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -(h + 28) - (index - 1) * (walletWidth + 18), 0, 6),
			size = UDim2.fromOffset(walletWidth, h - 12),
		})
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, h),
		BackgroundTransparency = 1,
	}, nodes)
end

return ToonMenuBar
