--!strict
--[=[
	DealChooserScreen: spends a one-time deal's waiting pick. On a gold ToonBackdrop with rays: the big gold title
	("PICK YOUR LEGENDARY!" / "PICK YOUR NEW HIRE!") and a plate under it, then one card per choice: the employee LIVE
	in that skin on a raised platform, the name, what comes with it, and a mint "Pick!" button. Only what the player
	does not own shows (DealViewModel.cards). No close button: the pick waits until it is spent. A press calls `onChoose`
	(DealServiceClient wires it to the server); the cosmetic reveal follows. Exempt (wires stores; values in DealViewModel).

	@class DealChooserScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local DealRules = require(ReplicatedStorage.Shared.Features.Deal.Rules.DealRules)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBackdrop = require(Toon.ToonBackdrop)
local ToonButton = require(Toon.ToonButton)
local ToonPill = require(Toon.ToonPill)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local VM = require(script.Parent.DealViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR

type Nodes = { [string]: React.ReactNode }

local function choiceCard(
	card: VM.Card,
	width: number,
	height: number,
	phone: boolean,
	order: number,
	onPick: () -> ()
): React.ReactNode
	local tint = InventoryViewModel.color(card.employee)
	local titleSize = if phone then 18 else 40
	local lineSize = if phone then 12 else 24
	local buttonHeight = if phone then 40 else 80
	local face: Nodes = {
		model = e(ToonViewport, {
			employee = card.employee,
			skin = card.skinKey,
			live = true,
			framing = "full",
			platform = { top = tint.body, side = tint.dark },
			position = UDim2.fromOffset(0, 6),
			size = UDim2.new(1, 0, 1, -(titleSize + lineSize + buttonHeight + 36)),
			zIndex = 3,
		}),
		title = e(ToonText, {
			text = string.upper(card.title),
			textSize = titleSize,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -(lineSize + buttonHeight + 26)),
			size = UDim2.new(1, -24, 0, titleSize + 6),
			align = "center",
			fit = true,
			zIndex = 4,
		}),
		line = e(ToonText, {
			text = card.line,
			font = "body",
			color = COLOR.white,
			textSize = lineSize,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -(buttonHeight + 20)),
			size = UDim2.new(1, -24, 0, lineSize + 4),
			align = "center",
			fit = true,
			zIndex = 4,
		}),
		pick = e(ToonButton, {
			variant = "primary",
			text = DealConstants.TEXT.pick,
			textSize = if phone then 20 else 40,
			sound = "cta",
			anchor = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -12),
			size = UDim2.new(1, -40, 0, buttonHeight),
			onActivated = onPick,
			zIndex = 5,
		}),
	}
	return e("Frame", {
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, {
		surface = e(ToonSurface, {
			hue = "grape",
			shade = { base = tint.body, hi = tint.light, lo = tint.dark },
			pattern = "bubbles",
			radius = 28,
			size = UDim2.new(1, 0, 1, -UIToonConstants.DEPTH.drop),
			children = face,
		}),
	})
end

export type DealChooserScreenProps = {
	onChoose: (deal: DealConstants.DealId, choice: string) -> (),
}

local function DealChooserScreen(props: DealChooserScreenProps): React.ReactNode
	local viewport = usePaperViewport()
	local phone = usePaperLayout() == "phone"
	local entitlements = ReactCharm.useAtom(StateSyncClientStore.entitlements)
	local deals = ReactCharm.useAtom(StateSyncClientStore.deals)
	local function owns(id: string): boolean
		return CosmeticRules.owns(entitlements, id)
	end
	local pending = DealRules.pending(deals, owns)
	if pending == nil then
		return nil
	end
	local deal = DealRules.deal(pending)
	local cards = VM.cards(pending, owns)

	local scale = PaperHudScaleViewModel.scale(viewport, if phone then "phone" else "desktop")
	local virtual =
		PaperHudScaleViewModel.virtual(viewport - Vector2.new(0, PaperHudScaleViewModel.topShift(scale)), scale)
	local layout = InventoryViewModel.layout(virtual, phone)
	local content = layout.content
	local titleSize = if phone then 40 else 96
	local top = layout.barY + titleSize + (if phone then 34 else 70)
	local height = math.max(0, virtual.Y - top - (if phone then 12 else 30))
	local gap = layout.gap * 2
	local count = math.max(1, #cards)
	local width = math.min(if phone then 220 else 460, math.floor((content.width - (count - 1) * gap) / count))

	local row: Nodes = {
		list = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, card in cards do
		row[card.id] = choiceCard(card, width, height, phone, index, function()
			props.onChoose(pending, card.id)
		end)
	end

	local screen: Nodes = {
		scaled = e(PaperHudFrame, {
			scale = scale,
			children = {
				title = e(ToonText, {
					text = deal.chooseTitle,
					textSize = titleSize,
					meaning = "gold",
					rotation = -2,
					anchor = Vector2.new(0.5, 0),
					position = UDim2.new(0.5, 0, 0, layout.barY),
					size = UDim2.fromOffset(math.floor(virtual.X * 0.7), titleSize + 12),
					align = "center",
					fit = true,
				}),
				sub = e(ToonPill, {
					text = deal.chooseLine,
					hue = "night",
					textSize = if phone then 13 else 24,
					padX = 24,
					anchor = Vector2.new(0.5, 0),
					position = UDim2.new(0.5, 0, 0, layout.barY + titleSize + (if phone then 4 else 10)),
					size = UDim2.fromOffset(if phone then 420 else 860, if phone then 26 else 50),
				}),
				row = e("Frame", {
					Position = UDim2.fromOffset(content.x, top),
					Size = UDim2.fromOffset(content.width, height),
					BackgroundTransparency = 1,
				}, row),
			},
		}),
	}
	return e(ToonBackdrop, {
		top = UIToonConstants.shade("gold").base,
		bottom = UIToonConstants.shade("coral").lo,
		rays = { position = UDim2.fromScale(0.5, 0.55), size = 0.8, color = COLOR.white, transparency = 0.55 },
		children = screen,
	})
end

return DealChooserScreen
