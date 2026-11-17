--!strict
--[=[
	LockerCardView: one Locker card in the Lockers tab's left column (LockerPanel): the Locker's render, key count, name,
	Odds button, pity line and meter, money on hand and the Open button. Split out of LockerPanel. Presentational
	(exempt; values specced in LockerViewModel.card / LockerCardViewModel).

	@class LockerCardView
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local LockerTypes = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerTypes)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBar = require(Toon.ToonBar)
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
local ToonPill = require(Toon.ToonPill)
local ToonPrice = require(Toon.ToonPrice)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.LockerViewModel)

local e = React.createElement
local COLOR, DEPTH = UIToonConstants.COLOR, UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }
type LockerId = LockerTypes.LockerId

local function LockerCardView(
	card: VM.LockerCard,
	selected: boolean,
	size: Vector2,
	phone: boolean,
	textSize: number,
	order: number,
	onSelect: (id: LockerId) -> (),
	onOpen: (id: LockerId) -> (),
	onOpenOdds: (id: LockerId) -> (),
	onGetGleam: () -> ()
): React.ReactNode
	local hue: UIToonConstants.Hue = if card.id == "gleam" then "gold" else "grape"
	local pad = if phone then 12 else 20
	local iconSize = math.floor(size.Y * 0.48)
	local pillWidth = math.floor(size.Y * 0.62)
	local nameSize = if phone then 20 else 36
	local buttonHeight = if phone then 38 else 64
	local rightX = pillWidth + pad + (if phone then 8 else 16)
	local rightWidth = size.X - rightX - pad
	local meter = card.meter
	local haveIcon: UIAssets.ToonIcon? = if card.haveCurrency == "acorns"
		then "acorns"
		elseif card.haveCurrency == "gloom" then "gloom"
		else nil
	local openContent: Nodes? = nil
	if card.button.kind == "buy" then
		local priced: Nodes = {
			price = e(ToonPrice, {
				currency = card.button.currency,
				amount = card.button.price,
				textSize = if phone then 18 else 30,
				meaning = "white",
				align = "center",
				size = UDim2.new(1, 0, 1, -DEPTH.lip),
			}),
		}
		openContent = priced
	end
	local face: Nodes = {
		art = e(ToonIcon, {
			icon = "locker",
			anchor = Vector2.new(0.5, 0.5),
			position = UDim2.new(0, pad + math.floor(pillWidth / 2), 0.42, 0),
			size = UDim2.fromOffset(iconSize, iconSize),
			drop = 5,
		}),
		-- How much of the Locker's own money you have (owner 11-16: Gloom shows here, not in the bars), above the button.
		have = if card.haveText ~= nil
			then e(ToonPill, {
				text = card.haveText,
				hue = "cream",
				meaning = if card.haveCurrency == "acorns" then "gold" else "grape",
				icon = haveIcon,
				-- Readable at the 75% laptop floor and on a phone (design px; the kit's 16 px / 12 pt floor).
				textSize = if phone then 15 else 26,
				iconSize = if phone then 32 else 56,
				anchor = Vector2.new(0, 1),
				position = UDim2.new(
					0,
					rightX + (if phone then 10 else 18),
					1,
					-DEPTH.lip - (if phone then 8 else 14) - buttonHeight - (if phone then 8 else 14)
				),
				size = UDim2.fromOffset(math.floor(rightWidth * 0.62), if phone then 28 else 48),
			})
			else nil,
		keys = e(ToonPill, {
			text = card.keysText,
			hue = "night",
			icon = "key",
			textSize = math.max(11, textSize - 5),
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, pad, 1, -DEPTH.lip - 8),
			size = UDim2.fromOffset(pillWidth, if phone then 24 else 38),
		}),
		name = e(ToonText, {
			text = string.upper(card.name),
			textSize = nameSize,
			position = UDim2.fromOffset(rightX, pad),
			size = UDim2.fromOffset(rightWidth - (if phone then 64 else 110), nameSize + 4),
			fit = true,
		}),
		odds = e(ToonButton, {
			variant = "secondary",
			text = "Odds",
			textSize = math.max(12, textSize - 2),
			small = true,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -pad, 0, pad),
			size = UDim2.fromOffset(if phone then 58 else 100, if phone then 26 else 42),
			onActivated = function()
				onOpenOdds(card.id)
			end,
		}),
		-- The pity meter (owner 11-16 pick A): big words and the kit's goo bar, filling one notch per open and
		-- emptying on an Epic or better; the plain line stays for an empty Locker or a restricted paid one.
		pity = if meter ~= nil
			then e(ToonText, {
				text = meter.text,
				textSize = if phone then 16 else 26,
				position = UDim2.fromOffset(rightX, pad + nameSize + (if phone then 8 else 14)),
				size = UDim2.fromOffset(rightWidth, (if phone then 16 else 26) + 6),
				fit = true,
			})
			else e(ToonText, {
				text = card.pityText,
				font = "body",
				color = if card.id == "gleam" then COLOR.ink else COLOR.white,
				textSize = math.max(12, textSize - 2),
				position = UDim2.fromOffset(rightX, pad + nameSize + 6),
				size = UDim2.fromOffset(rightWidth, textSize * 2 + 4),
				wrapped = true,
				fit = true,
			}),
		meter = if meter ~= nil
			then e(ToonBar, {
				kind = meter.kind,
				fill = meter.fill,
				label = meter.label,
				labelSize = if phone then 14 else 22,
				position = UDim2.fromOffset(
					rightX,
					pad + nameSize + (if phone then 8 else 14) + (if phone then 16 else 26) + (if phone then 8 else 12)
				),
				size = UDim2.fromOffset(math.floor(rightWidth * 0.8), if phone then 22 else 34),
			})
			else nil,
		open = e(ToonButton, {
			variant = if card.button.kind == "buy" or card.button.kind == "key"
				then "primary"
				elseif card.button.kind == "short" and card.button.enabled then "gleam"
				else "secondary",
			text = if openContent == nil then card.button.text else nil,
			content = openContent,
			textSize = if phone then 16 else 28,
			disabled = not card.button.enabled,
			-- Paying for an open plays the Shop's buy sound (owner pick B, 11-16), not the plain confirm.
			sound = if card.button.kind == "buy" or card.button.kind == "key" then "purchase" else nil,
			small = phone,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, rightX, 1, -DEPTH.lip - (if phone then 8 else 14)),
			size = UDim2.fromOffset(rightWidth, buttonHeight),
			onActivated = function()
				onSelect(card.id)
				if card.button.kind == "short" and card.button.enabled then
					onGetGleam()
				elseif card.button.enabled then
					onOpen(card.id)
				end
			end,
		}),
	}
	return e("TextButton", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		[React.Event.Activated] = function()
			onSelect(card.id)
		end,
	}, {
		surface = e(ToonSurface, {
			hue = hue,
			pattern = "rings",
			radius = 24,
			selected = selected,
			small = phone,
			size = UDim2.new(1, 0, 1, -DEPTH.drop),
			children = face,
		}),
	})
end

return LockerCardView
