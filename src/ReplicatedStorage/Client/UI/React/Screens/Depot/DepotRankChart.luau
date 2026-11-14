--!strict
--[=[
	DepotRankChart: the hub's rank chart in the V1 kit (p075 scene menus, owner yes 2026-11-14): a cream ToonPanel with
	the grape "RANKS" band and its X, the NEXT RANK card on the left (the next rank's real lanyard badge breaking its
	corner, the rank's name and level, the XP bar and what the rank gives; TOP RANK! once you are Big Boss) and a
	staircase on the right: one step per rank in its lanyard colour with its name, level and XP, each topped by the
	rank's real badge (DepotRankBadge), and on your own step your employee in your rank's pose (CharacterPortrait,
	`ladder`) under a gold YOU! pill. Ranks not reached yet are dimmed. Desktop 1420x860 design px, phone 732x344,
	scaled to the screen (DepotRankChartViewModel.fit). Presentational; the words are DepotRankChartViewModel.chart.

	@class DepotRankChart
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local VM = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotRankChartViewModel)
local DepotRankBadge = require(ReplicatedStorage.Client.UI.React.Screens.Depot.DepotRankBadge)
local CharacterPortrait = require(ReplicatedStorage.Client.UI.React.Screens.Portrait.CharacterPortrait)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonPanel = require(Toon.ToonPanel)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)

local e = React.createElement

local INK = UIToonConstants.COLOR.ink
local WHITE = Color3.new(1, 1, 1)
local LILAC = Color3.fromHex("C9A6FF")
local SOFT = Color3.fromHex("C4B5F0")
local YELLOW = Color3.fromHex("FFE066")
local GLOW = Color3.fromHex("B79CFF")

-- Every position below, per layout, in design px from the panel's top-left.
type Layout = {
	band: number,
	titleSize: number,
	subtitle: { x: number, y: number, w: number, h: number, size: number },
	card: { x: number, y: number, w: number, h: number },
	cardBadge: { w: number, h: number },
	text: { title: number, rank: number, body: number, get: number },
	bar: number,
	stairs: { x: number, floor: number, width: number, gap: number, base: number, step: number },
	stepText: { name: number, longName: number, level: number },
	badge: Vector2,
	portrait: Vector2,
	pill: { w: number, h: number, size: number },
}

local DESKTOP: Layout = {
	band = 118,
	titleSize = 76,
	subtitle = { x = 380, y = 22, w = 900, h = 76, size = 27 },
	card = { x = 40, y = 180, w = 470, h = 640 },
	cardBadge = { w = 170, h = 360 },
	text = { title = 30, rank = 44, body = 24, get = 21 },
	bar = 34,
	stairs = { x = 550, floor = 818, width = 112, gap = 12, base = 120, step = 46 },
	stepText = { name = 22, longName = 19, level = 16 },
	badge = Vector2.new(70, 150),
	portrait = Vector2.new(210, 250),
	pill = { w = 104, h = 44, size = 28 },
}

local PHONE: Layout = {
	band = 56,
	titleSize = 30,
	subtitle = { x = 150, y = 8, w = 500, h = 42, size = 14 },
	card = { x = 18, y = 74, w = 226, h = 250 },
	cardBadge = { w = 66, h = 140 },
	text = { title = 15, rank = 22, body = 13, get = 12 },
	bar = 16,
	stairs = { x = 262, floor = 326, width = 58, gap = 7, base = 74, step = 20 },
	stepText = { name = 13, longName = 12, level = 12 },
	badge = Vector2.new(26, 56),
	portrait = Vector2.new(96, 112),
	pill = { w = 52, h = 24, size = 14 },
}

export type DepotRankChartProps = {
	view: VM.View,
	phone: boolean,
	scale: number,
	onClose: () -> (),
}

-- A rank's lanyard colour as a depth-stack shade; a rank not reached yet is greyed toward the panel's lilac.
local function stepShade(colour: Color3, reached: boolean): UIToonConstants.Shade
	local base = if reached then colour else colour:Lerp(Color3.fromHex("8C86A8"), 0.6)
	return { base = base, hi = base:Lerp(WHITE, 0.45), lo = base:Lerp(Color3.new(0, 0, 0), 0.35) }
end

local function card(view: VM.View, l: Layout): { [string]: React.ReactNode }
	local c = l.card
	local nodes: { [string]: React.ReactNode } = {}
	nodes.cardSurface = e(ToonSurface, {
		hue = "night",
		position = UDim2.fromOffset(c.x, c.y),
		size = UDim2.fromOffset(c.w, c.h),
		radius = math.floor(c.w * 0.05),
		pattern = "bubbles",
		zIndex = 2,
	})
	local pad = math.floor(c.w * 0.06)
	nodes.cardTitle = e(ToonText, {
		text = view.card.title,
		textSize = l.text.title,
		color = if view.top then YELLOW else LILAC,
		position = UDim2.fromOffset(c.x + pad, c.y + pad),
		size = UDim2.fromOffset(c.w - l.cardBadge.w - pad, l.text.title + 6),
		fit = true,
		zIndex = 4,
	})
	nodes.cardBadge = e(DepotRankBadge, {
		rank = view.card.badge,
		position = UDim2.fromOffset(
			c.x + c.w - l.cardBadge.w - math.floor(pad * 0.3),
			c.y - math.floor(l.cardBadge.h * 0.12)
		),
		size = UDim2.fromOffset(l.cardBadge.w, l.cardBadge.h),
		rotation = 7,
		zIndex = 6,
	})
	local rankY = c.y + pad + l.text.title + math.floor(pad * 0.8)
	nodes.cardRank = e(ToonText, {
		text = string.gsub(view.card.rank, " ", "\n"),
		textSize = l.text.rank,
		position = UDim2.fromOffset(c.x + pad, rankY),
		size = UDim2.fromOffset(c.w - l.cardBadge.w - pad, l.text.rank * 2 + 8),
		wrapped = true,
		alignY = "top",
		zIndex = 4,
	})
	local levelY = rankY + l.text.rank * 2 + 16
	nodes.cardLevel = e(ToonText, {
		text = view.card.levelText,
		font = "body",
		textSize = l.text.body,
		color = WHITE,
		position = UDim2.fromOffset(c.x + pad, levelY),
		size = UDim2.fromOffset(c.w - 2 * pad, l.text.body + 6),
		zIndex = 4,
	})
	local barY = c.y + math.floor(c.h * 0.52)
	nodes.cardBar = e("Frame", {
		Position = UDim2.fromOffset(c.x + pad, barY),
		Size = UDim2.fromOffset(c.w - 2 * pad, l.bar),
		BackgroundColor3 = UIToonConstants.shade("night").lo,
		ZIndex = 4,
	}, {
		corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		stroke = e("UIStroke", { Color = INK, Thickness = math.max(3, math.floor(l.bar * 0.15)) }),
		fill = e("Frame", {
			Size = UDim2.fromScale(view.card.fraction, 1),
			BackgroundColor3 = WHITE,
			Visible = view.card.fraction > 0,
			ZIndex = 5,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			gradient = e("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHex("D9C2FF")),
					ColorSequenceKeypoint.new(0.45, Color3.fromHex("9B66F5")),
					ColorSequenceKeypoint.new(1, Color3.fromHex("7C3FCB")),
				}),
			}),
		}),
	})
	nodes.cardXp = e(ToonText, {
		text = view.card.xpText,
		font = "body",
		textSize = l.text.body - 2,
		color = SOFT,
		position = UDim2.fromOffset(c.x + pad, barY + l.bar + 8),
		size = UDim2.fromOffset(c.w - 2 * pad, l.text.body + 4),
		zIndex = 4,
	})
	local listY = barY + l.bar + 8 + l.text.body + math.floor(pad * 0.9)
	if not view.top then
		nodes.cardGets = e(ToonText, {
			text = "You get:",
			font = "body",
			textSize = l.text.get + 1,
			color = YELLOW,
			position = UDim2.fromOffset(c.x + pad, listY),
			size = UDim2.fromOffset(c.w - 2 * pad, l.text.get + 6),
			zIndex = 4,
		})
		listY += l.text.get + 10
	end
	local dot = math.max(8, math.floor(l.text.get * 0.75))
	for index, line in view.card.gets do
		local y = listY + (index - 1) * math.floor(l.text.get * 1.55)
		nodes[`cardDot{index}`] = e("Frame", {
			Position = UDim2.fromOffset(c.x + pad, y + math.floor((l.text.get + 4 - dot) / 2)),
			Size = UDim2.fromOffset(dot, dot),
			BackgroundColor3 = UIToonConstants.shade("grape").hi,
			ZIndex = 4,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = INK, Thickness = 2 }),
		})
		nodes[`cardGet{index}`] = e(ToonText, {
			text = line,
			font = "body",
			textSize = l.text.get,
			color = WHITE,
			position = UDim2.fromOffset(c.x + pad + dot + 8, y),
			size = UDim2.fromOffset(c.w - 2 * pad - dot - 8, l.text.get + 4),
			fit = true,
			zIndex = 4,
		})
	end
	return nodes
end

local function stairs(view: VM.View, l: Layout): { [string]: React.ReactNode }
	local s = l.stairs
	local nodes: { [string]: React.ReactNode } = {}
	for index, step in view.steps do
		local height = s.base + s.step * (index - 1)
		local x = s.x + (index - 1) * (s.width + s.gap)
		local top = s.floor - height
		local lift = if step.here then math.floor(s.step * 0.18) else 0
		nodes[`step{index}`] = e(ToonSurface, {
			hue = "cream",
			shade = stepShade(step.colour, step.reached),
			position = UDim2.fromOffset(x, top - lift),
			size = UDim2.fromOffset(s.width, height),
			radius = math.floor(s.width * 0.15),
			small = l == PHONE,
			zIndex = 3,
		})
		if step.here then
			nodes[`glow{index}`] = e("Frame", {
				Position = UDim2.fromOffset(x - 2, top - lift - 2),
				Size = UDim2.fromOffset(s.width + 4, height + 4),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, math.floor(s.width * 0.15)) }),
				stroke = e("UIStroke", { Color = GLOW, Thickness = if l == PHONE then 4 else 7 }),
			})
		end
		local long = string.find(step.name, " ", 1, true) ~= nil
		local nameSize = if long then l.stepText.longName else l.stepText.name
		local nameLines = if long then 2 else 1
		local textTop = top - lift + math.floor(s.width * 0.12)
		nodes[`name{index}`] = e(ToonText, {
			text = string.gsub(step.name, " ", "\n"),
			textSize = nameSize,
			align = "center",
			alignY = "top",
			position = UDim2.fromOffset(x, textTop),
			size = UDim2.fromOffset(s.width, nameSize * nameLines + 4),
			wrapped = true,
			zIndex = 5,
		})
		nodes[`level{index}`] = e(ToonText, {
			text = `{step.levelText}\n{step.xpText}`,
			font = "body",
			textSize = l.stepText.level,
			color = WHITE,
			align = "center",
			alignY = "top",
			position = UDim2.fromOffset(x, textTop + nameSize * nameLines + 4),
			size = UDim2.fromOffset(s.width, l.stepText.level * 2 + 6),
			wrapped = true,
			zIndex = 5,
		})
		local centre = x + s.width / 2
		if step.here then
			nodes.you = e(CharacterPortrait, {
				userId = Players.LocalPlayer.UserId,
				context = "ladder",
				level = step.level,
				framing = "full",
				anchor = Vector2.new(0.5, 1),
				position = UDim2.fromOffset(centre, top - lift + math.floor(s.step * 0.15)),
				size = UDim2.fromOffset(l.portrait.X, l.portrait.Y),
				zIndex = 6,
			})
			nodes.youPill = e(ToonPill, {
				text = "YOU!",
				hue = "gold",
				meaning = "white",
				textSize = l.pill.size,
				anchor = Vector2.new(0.5, 1),
				position = UDim2.fromOffset(centre, top - lift - l.portrait.Y + math.floor(l.portrait.Y * 0.06)),
				size = UDim2.fromOffset(l.pill.w, l.pill.h),
				tilt = -3,
				zIndex = 7,
			})
		else
			nodes[`badge{index}`] = e(DepotRankBadge, {
				rank = step.level,
				anchor = Vector2.new(0.5, 1),
				position = UDim2.fromOffset(centre, top - 4),
				size = UDim2.fromOffset(l.badge.X, l.badge.Y),
				faded = not step.reached,
				zIndex = 4,
			})
		end
	end
	return nodes
end

local function DepotRankChart(props: DepotRankChartProps): React.ReactNode
	local l = if props.phone then PHONE else DESKTOP
	local size = if props.phone then VM.PHONE_SIZE else VM.SIZE
	local view = props.view
	local overlay: { [string]: React.ReactNode } = {}
	overlay.subtitle = e(ToonText, {
		text = view.subtitle,
		font = "body",
		textSize = l.subtitle.size,
		color = WHITE,
		position = UDim2.fromOffset(l.subtitle.x, l.subtitle.y),
		size = UDim2.fromOffset(l.subtitle.w, l.subtitle.h),
		alignY = "center",
		wrapped = true,
		zIndex = 4,
	})
	for key, node in card(view, l) do
		overlay[key] = node
	end
	for key, node in stairs(view, l) do
		overlay[key] = node
	end
	return e("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
	}, {
		scale = e("UIScale", { Scale = props.scale }),
		panel = e(ToonPanel, {
			size = size,
			pop = true,
			header = { title = "RANKS", hue = "grape", height = l.band, titleSize = l.titleSize },
			onClose = props.onClose,
			overlay = overlay,
		}),
	})
end

return DepotRankChart
