--!strict
--[=[
	LockerInsideCard: one item card in a Locker's "What's inside" grid (LockerPanel): a rarity-coloured card with the item
	in 3D (or the sticker icon), its rarity flag, name, line, direct Gleam price and Owned stamp. Tapping it opens the
	item's own page. Split out of LockerPanel. Presentational (exempt; values specced in LockerViewModel.inside).

	@class LockerInsideCard
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonPrice = require(Toon.ToonPrice)
local ToonStamp = require(Toon.ToonStamp)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.LockerViewModel)

local e = React.createElement
local COLOR, DEPTH = UIToonConstants.COLOR, UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

local function itemArt(item: VM.InsideItem): React.ReactNode
	if item.kind == "stickerPack" or item.kind == "sticker" then
		return e(ToonIcon, {
			icon = "stickers",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			size = UDim2.fromScale(0.7, 0.7),
			drop = 4,
		})
	end
	local vacuum = item.vacuum
	return e(ToonViewport, {
		employee = if vacuum ~= nil then nil else item.employee,
		vacuum = if vacuum ~= nil then CosmeticRegistry.keyOf(vacuum) else nil,
		skin = item.skinKey,
		framing = "full",
		size = UDim2.fromScale(1, 1),
	})
end

local function LockerInsideCard(
	item: VM.InsideItem,
	size: Vector2,
	phone: boolean,
	order: number,
	onOpen: (item: VM.InsideItem) -> ()
): React.ReactNode
	local shade = UIToonConstants.rarity(item.rarity)
	local nameSize = if phone then 13 else 22
	local footer = math.floor(nameSize * 2.5)
	local face: Nodes = {
		stage = e("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 1, -footer - 8 - DEPTH.lip),
			BackgroundColor3 = COLOR.white,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }),
			gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(shade.hi, shade.base) }),
			art = itemArt(item),
		}),
		name = e(ToonText, {
			text = item.name,
			textSize = nameSize,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 10, 1, -DEPTH.lip - math.floor(nameSize * 1.15)),
			size = UDim2.new(0.64, -10, 0, nameSize + 4),
			fit = true,
			zIndex = 3,
		}),
		line = e(ToonText, {
			text = item.line,
			font = "body",
			color = COLOR.white,
			textSize = math.max(if phone then 11 else 15, nameSize - 7),
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, 10, 1, -DEPTH.lip - 4),
			size = UDim2.new(0.64, -10, 0, nameSize),
			fit = true,
			zIndex = 3,
		}),
		price = if not item.owned and item.directPrice ~= nil
			then e(ToonPrice, {
				currency = "gleam",
				amount = item.directPrice,
				textSize = nameSize,
				anchor = Vector2.new(1, 1),
				position = UDim2.new(1, -8, 1, -DEPTH.lip - 6),
				size = UDim2.new(0.38, 0, 0, nameSize + 10),
				zIndex = 3,
			})
			else nil,
	}
	local nodes: Nodes = {
		surface = e(ToonSurface, {
			hue = "grape",
			shade = { base = shade.lo:Lerp(shade.base, 0.4), hi = shade.base, lo = shade.lo },
			radius = 20,
			small = phone,
			gloss = false,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		}),
		rarity = e(ToonFlag, {
			text = string.upper(item.rarity),
			rarity = item.rarity,
			tilt = -5,
			textSize = if phone then 10 else 14,
			position = UDim2.fromOffset(-6, -8),
			size = UDim2.fromOffset(if phone then 70 else 120, if phone then 20 else 28),
			zIndex = 7,
		}),
		owned = if item.owned
			then e(ToonStamp, {
				text = "OWNED",
				size = math.floor(math.min(size.X, size.Y) * 0.48),
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.42),
				zIndex = 6,
			})
			else nil,
	}
	-- Every card opens the item's own page (LockerItemPanel), where a direct buy lives.
	return e("TextButton", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		[React.Event.Activated] = function()
			onOpen(item)
		end,
	}, nodes)
end

return LockerInsideCard
