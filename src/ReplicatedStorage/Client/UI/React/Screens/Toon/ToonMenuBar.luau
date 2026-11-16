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
local TextService = game:GetService("TextService")

local React = require(ReplicatedStorage.Packages.React)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonMenuBarViewModel = require(Toon.ToonMenuBarViewModel)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonWallet = require(Toon.ToonWallet)
local ToonWipe = require(Toon.ToonWipe)
local UIToonConstants = require(Toon.UIToonConstants)
local useToonPlay = require(Toon.useToonPlay)

local e = React.createElement

-- A tab word's drawn width at `size` (the kit's display face, Luckiest Guy).
local function measure(text: string, size: number): number
	return TextService:GetTextSize(text, size, Enum.Font.LuckiestGuy, Vector2.new(10000, 1000)).X
end

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
	-- The bar's whole width (design px): when given, the tabs shrink to fit between the title and the wallets.
	width: number?,
}

-- How long a scrolling tab row takes to bring the tab picked into view (U1).
local SCROLL_SECONDS = 0.25

local function easeOut(t: number): number
	return 1 - (1 - t) * (1 - t)
end

-- A small gold chevron on a night disc at a scrolling tab row's edge, pointing to the side that still hides tabs (drawn
-- from two bars: the kit draws no arrow glyphs). `side` 1 points right, -1 left.
local function chevron(side: number, size: number, position: UDim2, visible: boolean): React.ReactNode
	local bars: { [string]: React.ReactNode } = {
		corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		stroke = e("UIStroke", { Color = UIToonConstants.COLOR.ink, Thickness = 3 }),
	}
	for index, tilt in { 45, -45 } do
		bars[`bar{index}`] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * 2, 0.5, (if index == 1 then -1 else 1) * size * 0.14),
			Size = UDim2.fromOffset(size * 0.42, math.max(4, size * 0.14)),
			Rotation = side * tilt,
			BackgroundColor3 = UIToonConstants.shade("gold").base,
			BorderSizePixel = 0,
		}, { corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = UIToonConstants.shade("night").base,
		BorderSizePixel = 0,
		Visible = visible,
		ZIndex = 6,
	}, bars)
end

local function ToonMenuBar(props: ToonMenuBarProps): React.ReactNode
	local h = props.height
	local phone = props.phone
	local nodes: { [string]: React.ReactNode } = {}
	-- A scrolling tab row (U1): where the player left it, which sides still hide tabs, and the glide that brings the
	-- tab picked into view.
	local scrolled = React.useRef(0)
	local more, setMore = React.useState({ left = false, right = true })
	local glide = useToonPlay(SCROLL_SECONDS, 0, props.current or "")
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
	local plateOverlay: { [string]: React.ReactNode } = {}
	plateOverlay.wipe = e(ToonWipe, { radius = 22, zIndex = 50 })
	nodes.plate = e(ToonSurface, {
		hue = props.hue or "grape",
		radius = 22,
		position = UDim2.fromOffset(x + math.floor(art * 0.3), 2),
		size = UDim2.fromOffset(plateWidth, h - 4),
		children = plateFace,
		-- The menu arrives goo-smeared and a squeegee wipes the plate clean (owner pick M2, 2026-11-16).
		overlay = plateOverlay,
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

	-- The tabs, sized from their measured words to the room between the plate and the wallets
	-- (ToonMenuBarViewModel.tabs): shrunk to the readable floor, then without icons, else scrolling sideways.
	local walletWidth = if phone then 120 else 190
	local tabGap = if phone then 8 else 12
	local baseText = math.floor(h * 0.4)
	local inputs: { ToonMenuBarViewModel.TabInput } = {}
	for _, tab in props.tabs do
		table.insert(inputs, { text = tab.text, icon = tab.icon ~= nil })
	end
	local barWidth = props.width
	local room = if barWidth ~= nil then barWidth - x - (h + 28) - 2 * (walletWidth + 18) - tabGap else math.huge
	local fitted = ToonMenuBarViewModel.tabs(
		inputs,
		room,
		baseText,
		if phone then UIPaperConstants.TEXT_MIN.phone else UIPaperConstants.TEXT_MIN.desktop,
		tabGap,
		measure
	)
	local tabText = fitted.textSize
	local tabNodes: { [string]: React.ReactNode } = {}
	-- Scrolling tabs are laid out from the scroller's left; fixed ones from the bar's. The scroller reaches HEADROOM px
	-- above the bar so it does not clip the selected tab's lift or a Soon flag.
	local HEADROOM = ToonMenuBarViewModel.SELECTED_REACH
	local tabX = if fitted.scroll then 0 else x
	local tabTop = ToonMenuBarViewModel.TAB_TOP
	local tabY = if fitted.scroll then tabTop + HEADROOM else tabTop
	for index, tab in props.tabs do
		local width = fitted.widths[index]
		local selected = tab.id == props.current
		local soon = tab.soon == true
		tabNodes[`tab{index}`] = e(ToonButton, {
			variant = if soon then "secondary" else if selected then "gleam" else "grape",
			sound = "tab",
			text = tab.text,
			icon = if fitted.icons then tab.icon else nil,
			textSize = tabText,
			disabled = soon,
			selected = selected,
			position = UDim2.fromOffset(tabX, tabY),
			size = UDim2.fromOffset(width, h - 14),
			onActivated = function()
				if not soon then
					props.onTab(tab.id)
				end
			end,
		})
		if soon then
			-- Over the tab's top-right corner, kept inside the bar (the screen's edge would cut a flag above it),
			-- and wide enough for the whole word next to the notch. In a scroller it sits on the tab's top edge.
			local flagText = if phone then 13 else 17
			tabNodes[`soon{index}`] = e(ToonFlag, {
				text = "Soon",
				hue = "coral",
				tilt = 6,
				textSize = flagText,
				anchor = Vector2.new(1, 0),
				position = UDim2.fromOffset(tabX + width + 16, tabY - 14),
				size = UDim2.fromOffset(math.floor(4 * flagText * 0.75) + 44, if phone then 22 else 28),
				zIndex = 5,
			})
		end
		tabX += width + tabGap
	end
	local view = math.max(0, room)
	local canvasWidth = tabX + 16
	local currentIndex = 0
	for index, tab in props.tabs do
		if tab.id == props.current then
			currentIndex = index
		end
	end
	-- Made once per tab picked, so a re-render never pulls the row back from where the player dragged it.
	local canvasDeps: { unknown } = { props.current or "", fitted.scroll }
	local canvas = React.useMemo(function(): React.Binding<Vector2>
		local from = scrolled.current or 0
		local to = ToonMenuBarViewModel.scrollTo(fitted.widths, tabGap, currentIndex, view, from)
		return glide:map(function(t: number): Vector2
			return Vector2.new(from + (to - from) * easeOut(t), 0)
		end)
	end, canvasDeps)
	if fitted.scroll then
		nodes.tabs = e("ScrollingFrame", {
			Position = UDim2.fromOffset(x, -HEADROOM),
			Size = UDim2.fromOffset(view, h + HEADROOM),
			CanvasSize = UDim2.fromOffset(canvasWidth, h + HEADROOM),
			CanvasPosition = canvas,
			[React.Change.CanvasPosition] = function(frame: ScrollingFrame)
				local at = frame.CanvasPosition.X
				scrolled.current = at
				local now = ToonMenuBarViewModel.more(at, canvasWidth, view)
				if now.left ~= more.left or now.right ~= more.right then
					setMore(now)
				end
			end,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Selectable = false,
		}, tabNodes)
		-- The row's edges say when tabs hide past them (U1).
		local hint = if phone then 28 else 36
		local hintY = tabTop + math.floor((h - 14) / 2)
		nodes.moreLeft = chevron(-1, hint, UDim2.fromOffset(x + hint * 0.5, hintY), more.left)
		nodes.moreRight = chevron(1, hint, UDim2.fromOffset(x + view - hint * 0.5, hintY), more.right)
	else
		for key, node in tabNodes do
			nodes[key] = node
		end
	end

	-- The wallets and the close, from the right.
	local walletText = math.floor(h * 0.44)
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
		-- The balance counts to a new one, bumping when it grows (M5).
		nodes[wallet.id] = e(ToonWallet, {
			amount = wallet.amount,
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
