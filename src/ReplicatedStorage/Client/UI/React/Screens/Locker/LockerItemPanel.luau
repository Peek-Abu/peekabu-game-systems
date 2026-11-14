--!strict
--[=[
	LockerItemPanel: a Locker "What's inside" item's own page, laid out like the Shop's product page (owner, 2026-11-14:
	locker items should be viewable on a product-page screen). Left, a cream panel: the rarity flag, the big name, the
	item's line, which Locker it comes from and its chance each open, and one button (LockerViewModel.itemPage: the
	direct buy where the card offers it, Get Gleam when that buy is too dear, else Back), with Back under a buy. Right:
	the item LIVE on a platform in its rarity's colour, which the player can spin; nothing is drawn over it.
	Presentational (exempt; values specced in LockerViewModel).

	@class LockerItemPanel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local VM = require(script.Parent.LockerViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

export type LockerItemPanelProps = {
	item: VM.InsideItem,
	page: VM.ItemPage,
	layout: InventoryViewModel.Layout,
	onBack: () -> (),
	onBuy: () -> (),
	onGetGleam: () -> (),
}

local function LockerItemPanel(props: LockerItemPanelProps): React.ReactNode
	local item, page, layout = props.item, props.page, props.layout
	local phone = layout.phone
	local size = layout.textSize
	-- The same split as the Shop's product page, so the backdrop's rays and tier word centre on the model.
	local width = math.floor(layout.content.width * (if phone then 0.52 else 0.4))
	local pad = if phone then 12 else 26
	local inner = width - 2 * pad
	local nameSize = math.floor(layout.headingSize * (if phone then 0.9 else 1.25))
	local shade = UIToonConstants.rarity(item.rarity)
	local buttonHeight = if phone then 44 else 90
	local backHeight = if phone then 32 else 56
	local lineY = pad + (if phone then 34 else 56) + nameSize + 8

	local face: Nodes = {
		rarity = e(ToonFlag, {
			text = if item.rarity == "default" then "CLASSIC" else string.upper(item.rarity),
			rarity = item.rarity,
			tilt = -3,
			textSize = if phone then 13 else 22,
			position = UDim2.fromOffset(pad, pad),
			size = UDim2.fromOffset(if phone then 110 else 180, if phone then 26 else 40),
		}),
		name = e(ToonText, {
			text = string.upper(item.name),
			textSize = nameSize,
			position = UDim2.fromOffset(pad, pad + (if phone then 34 else 56)),
			size = UDim2.fromOffset(inner, nameSize + 8),
			fit = true,
		}),
		line = e(ToonText, {
			text = item.line,
			font = "body",
			color = UIToonConstants.shade("grape").base,
			textSize = size,
			position = UDim2.fromOffset(pad, lineY),
			size = UDim2.fromOffset(inner, size + 4),
			fit = true,
		}),
		from = e(ToonText, {
			text = page.from,
			font = "body",
			color = COLOR.ink,
			textSize = size,
			position = UDim2.fromOffset(pad, lineY + size + 16),
			size = UDim2.fromOffset(inner, size * 3),
			wrapped = true,
			alignY = "top",
		}),
		chance = if page.chance ~= nil
			then e(ToonText, {
				text = page.chance,
				font = "body",
				color = UIToonConstants.shade("steel").lo,
				textSize = size - 2,
				position = UDim2.fromOffset(pad, lineY + size * 4 + 20),
				size = UDim2.fromOffset(inner, size * 2),
				wrapped = true,
				alignY = "top",
			})
			else nil,
	}
	local bottom = pad
	if page.button ~= "back" then
		face.back = e(ToonButton, {
			variant = "secondary",
			text = "Back",
			textSize = if phone then 14 else 24,
			small = true,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, pad, 1, -bottom),
			size = UDim2.fromOffset(if phone then 90 else 160, backHeight),
			onActivated = props.onBack,
		})
		bottom += backHeight + 10
	end
	face.button = e(ToonButton, {
		variant = if page.button == "back" then "secondary" else "primary",
		text = if page.button == "buy"
			then `Buy for {item.directPrice} Gleam`
			elseif page.button == "getGleam" then "Get more Gleam"
			else "Back",
		textSize = if phone then 18 else 32,
		anchor = Vector2.new(0, 1),
		position = UDim2.new(0, pad, 1, -bottom),
		size = UDim2.fromOffset(inner, buttonHeight),
		onActivated = if page.button == "buy"
			then props.onBuy
			elseif page.button == "getGleam" then props.onGetGleam
			else props.onBack,
	})

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		panel = e(ToonSurface, {
			hue = "cream",
			pattern = "rings",
			radius = 28,
			size = UDim2.new(0, width, 1, -DEPTH.drop),
			children = face,
		}),
		hero = e("Frame", {
			Position = UDim2.fromOffset(width + layout.gap, 0),
			Size = UDim2.new(1, -width - layout.gap, 1, 0),
			BackgroundTransparency = 1,
		}, {
			model = e(ToonViewport, {
				employee = if item.vacuum ~= nil then nil else item.employee,
				vacuum = if item.vacuum ~= nil then CosmeticRegistry.keyOf(item.vacuum) else nil,
				skin = item.skinKey,
				live = item.vacuum == nil,
				spin = true,
				-- An emote's page loops it on its employee; an idle's plays it in the Classic skin.
				emote = if item.kind == "emote" then item.id else nil,
				idle = if item.kind == "idle" then string.match(item.id, "^[^%.]+%.(.+)$") else nil,
				framing = "full",
				platform = { top = shade.base, side = shade.lo },
				size = UDim2.fromScale(1, 0.96),
				zIndex = 3,
			}),
		}),
	})
end

return LockerItemPanel
