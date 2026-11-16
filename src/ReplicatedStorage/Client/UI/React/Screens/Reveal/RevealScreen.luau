--!strict
--[=[
	RevealScreen: "you got it!" after a purchase, a grant or the first-join pick (concepts:
	characters/ui/character-ui/frames4/reveal-leg.jpg and reveal-hire.jpg). On a ToonBackdrop in the rarity's colour
	(rays from Rare, stripes from Epic, confetti for Legendary): the title popping in ("LEGENDARY!"), a ribbon ("New
	skin for Pippa"), the item LIVE on a raised platform with its name plate, and the buttons (the main one's words fit
	the item: Wear it!, Use it!, Add to wheel!, Use stickers!; Later, or Nice!). A buy with more than one item shows a
	"YOU GOT" tile for each: tapping one puts it in front with its own button, the screen stays open after using one,
	and Done leaves. An emote's Add to wheel! and a sticker pack's Use stickers! open a small picker over the reveal
	(RevealSlotPicker: the emote's wheel, or the pack's stickers and your spots); closing it leaves you on the reveal. A hire shows the ID card stamped HIRED!, the ability card and Start! or Equip!. Reads
	CosmeticRevealStore.current (one at a time); a button moves the queue on, and the main button sends the changes
	through CosmeticServiceClient. Values are RevealViewModel's. Exempt (wires stores; story in RevealScreen.story).
	The confetti is RevealConfetti, the bottom-left cards (ID card and ability, what it does, YOU GOT tiles)
	RevealSideCards, and the colour style chips RevealStyleChips.

	@class RevealScreen
]=]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticOutfitRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticOutfitRules)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local CosmeticServiceClient = require(ReplicatedStorage.Client.Features.Cosmetic.CosmeticServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local CosmeticRevealStore = require(ReplicatedStorage.Client.Features.Cosmetic.State.CosmeticRevealStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBackdrop = require(Toon.ToonBackdrop)
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local ToonMotionViewModel = require(Toon.ToonMotionViewModel)
local useToonPlay = require(Toon.useToonPlay)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local VM = require(script.Parent.RevealViewModel)
local RevealSlotPicker = require(script.Parent.RevealSlotPicker)
local RevealConfetti = require(script.Parent.RevealConfetti)
local RevealSideCards = require(script.Parent.RevealSideCards)
local RevealStyleChips = require(script.Parent.RevealStyleChips)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

export type RevealScreenProps = {
	-- A fixed reveal instead of the store (the story).
	reveal: VM.Reveal?,
	viewport: Vector2?,
	phone: boolean?,
}

local function RevealScreen(props: RevealScreenProps): React.ReactNode
	local liveViewport = usePaperViewport()
	local livePhone = usePaperLayout() == "phone"
	local stored = ReactCharm.useAtom(CosmeticRevealStore.current)
	local loadout = ReactCharm.useAtom(StateSyncClientStore.loadout)
	local entitlements = ReactCharm.useAtom(StateSyncClientStore.entitlements)
	local reveal = props.reveal or stored
	local noScale: UIScale? = nil
	local pop, setPop = React.useState(noScale)

	local bought = if reveal ~= nil then reveal.purchase else nil
	local key = if reveal ~= nil
		then table.concat(reveal.ids, ",") .. (if bought ~= nil
			then `#{bought.kind}:{bought.key}:{bought.amount}`
			else "")
		else ""
	-- Which item is in front (a buy with more than one), for the reveal it was tapped on (a new reveal starts at 1).
	local focused, setFocused = React.useState({ key = "", focus = 1 })
	local focus = if focused.key == key then focused.focus else 1
	-- The colour style picked to wear, for the item it was picked on (a new one starts at style 1).
	local styleKey = `{key}#{focus}`
	local picked, setPicked = React.useState({ key = "", style = 1 })
	-- The small picker open over the reveal, for the item it was opened on.
	local picking, setPicking = React.useState("")
	local style = if picked.key == styleKey then picked.style else 1
	-- The opening, replayed for each reveal: a white flash fading, the character popping in, a bright sweep.
	local flash = useToonPlay(0.5, 0, key)
	local hero = useToonPlay(0.55, 0.15, key)
	local sweep = useToonPlay(0.9, 0.35, key)
	-- The title pops in: 0.4 -> 1 with an overshoot.
	local deps: { unknown } = { pop, key }
	React.useEffect(function(): () -> ()
		if pop == nil then
			return function() end
		end
		-- Reduced Motion (the device setting): the title is simply there, no pop.
		if GuiService.ReducedMotionEnabled then
			pop.Scale = 1
			return function() end
		end
		pop.Scale = 0.4
		local tween = TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		})
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, deps)

	if reveal == nil then
		return nil
	end
	local function owns(id: string): boolean
		return CosmeticRules.owns(entitlements, id)
	end
	local view = VM.view(reveal, { loadout = loadout, owns = owns, focus = focus })
	local viewport = props.viewport or liveViewport
	local phone = if props.phone ~= nil then props.phone else livePhone
	local scale = PaperHudScaleViewModel.scale(viewport, if phone then "phone" else "desktop")
	local virtual =
		PaperHudScaleViewModel.virtual(viewport - Vector2.new(0, PaperHudScaleViewModel.topShift(scale)), scale)
	local layout = InventoryViewModel.layout(virtual, phone)
	local size = layout.textSize
	local shade = UIToonConstants.rarity(view.rarity)
	local tint = if view.kind == "hire" then InventoryViewModel.color(view.employee) else nil
	local top = if tint ~= nil then tint.body else shade.base
	local bottom = if tint ~= nil then tint.dark else shade.lo

	local function finish(equip: boolean)
		if props.reveal ~= nil then
			return
		end
		if equip and view.picker ~= nil then
			-- An emote or a sticker pack: the small picker opens over the reveal.
			setPicking(styleKey)
			return
		end
		if equip then
			for _, change in VM.wear(view, style) do
				CosmeticServiceClient:requestEquip(change)
			end
			-- A buy with more than one item stays open: the player can use the other items, then Done.
			if view.stays then
				return
			end
		end
		CosmeticRevealStore.next()
	end

	local titleSize = if phone then 50 else 130
	local nodes: Nodes = {
		-- The title in a frame that pops (its UIScale is tweened on mount).
		title = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, layout.barY),
			Size = UDim2.fromOffset(math.floor(virtual.X * 0.6), titleSize + 16),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, {
			scale = e("UIScale", { ref = setPop }),
			text = e(ToonText, {
				text = view.title,
				textSize = titleSize,
				meaning = "gold",
				rotation = -3,
				size = UDim2.fromScale(1, 1),
				align = "center",
				fit = true,
				zIndex = 5,
			}),
		}),
		ribbon = e(ToonFlag, {
			text = view.ribbon,
			hue = "grape",
			tilt = -3,
			textSize = if phone then 15 else 30,
			anchor = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, layout.barY + titleSize + (if phone then 8 else 20)),
			size = UDim2.fromOffset(if phone then 230 else 460, if phone then 30 else 56),
			zIndex = 5,
		}),
	}

	-- The hero on its platform, the name plate under it.
	local heroTop = layout.barY + titleSize + (if phone then 46 else 90)
	local heroHeight = virtual.Y - heroTop - (if phone then 10 else 30)
	local heroWidth = math.floor(virtual.X * 0.36)
	local heroX = if view.kind == "hire" then 0.6 else 0.5
	local plate: Nodes = {
		name = e(ToonText, {
			text = string.upper(view.name),
			textSize = if phone then 22 else 56,
			position = UDim2.fromOffset(16, 0),
			size = UDim2.new(1, -32, 1, -DEPTH.lip),
			align = "center",
			fit = true,
		}),
	}
	local newVacuum = view.vacuum
	local tryOn = if newVacuum ~= nil
		then CosmeticOutfitRules.tryOn(
			CosmeticOutfitRules.current(loadout, function(id: string): boolean
				return CosmeticRules.owns(entitlements, id)
			end),
			newVacuum
		)
		else nil
	nodes.hero = e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(heroX, 0, 0, heroTop),
		Size = UDim2.fromOffset(heroWidth, heroHeight),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, {
		pop = e("UIScale", {
			Scale = hero:map(function(alpha: number): number
				return if alpha <= 0 then 0.01 else ToonMotionViewModel.pop(alpha)
			end),
		}),
		-- A purchase shows its picture (the Gleam pack, the pass, the cup); a sticker pack its stickers; anything else
		-- the model.
		model = if view.art ~= nil
			then e(ToonIcon, {
				icon = view.art.icon,
				image = view.art.image,
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.42),
				size = UDim2.fromScale(0.8, 0.6),
				zIndex = 3,
			})
			elseif view.stickers then e(ToonIcon, {
				icon = "stickers",
				anchor = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.42),
				size = UDim2.fromScale(0.8, 0.5),
				zIndex = 3,
			})
			else e(ToonViewport, {
				-- A new vacuum is shown on you, from behind.
				employee = if tryOn == nil then view.employee else nil,
				outfit = tryOn,
				turn = if tryOn ~= nil then 150 else nil,
				skin = view.skinKey,
				style = style,
				live = true,
				-- An idle plays as itself, an emote loops.
				idle = view.idle,
				emote = view.emote,
				-- A hire, and every new skin (owner, 2026-10-29), plays its reveal once, then its idle.
				reveal = tryOn == nil and (view.kind == "hire" or view.skinKey ~= nil) and focus == 1,
				framing = "full",
				-- A hire stands on their own colour; an item on its rarity's.
				platform = { top = if tint ~= nil then tint.body else shade.base, side = bottom },
				size = UDim2.fromScale(1, 0.85),
				zIndex = 3,
			}),
		plate = e(ToonSurface, {
			hue = "grape",
			radius = 22,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.fromScale(0.5, 1),
			size = UDim2.new(0.9, 0, 0, if phone then 40 else 92),
			zIndex = 4,
			children = plate,
		}),
	})
	if view.effects.sparkles then
		nodes.sparkles = e(ToonSparkle, {
			spots = {
				{ position = UDim2.fromScale(0.34, 0.35), size = if phone then 24 else 56 },
				{ position = UDim2.fromScale(0.66, 0.42), size = if phone then 18 else 44 },
				{ position = UDim2.fromScale(0.62, 0.72), size = if phone then 14 else 32 },
			},
			zIndex = 6,
		})
	end

	-- Bottom left: what came with it, or (a hire) the ID card and the ability.
	local margin = if phone then 12 else 60
	local leftWidth = math.floor(virtual.X * 0.3)
	RevealSideCards.add(nodes, view, phone, size, margin, leftWidth, heroTop, key, setFocused)

	-- Bottom right: the buttons.
	local buttonWidth = math.floor(virtual.X * (if phone then 0.26 else 0.2))
	local buttonHeight = if phone then 46 else 96
	nodes.primary = e(ToonButton, {
		variant = "primary",
		text = view.primary,
		-- Already on, or nothing to put on while the screen stays open: greyed (Done leaves).
		disabled = view.done or (view.stays and #view.changes == 0 and view.picker == nil),
		textSize = if phone then 22 else 46,
		sound = "cta",
		anchor = Vector2.new(1, 1),
		position = UDim2.new(
			1,
			-margin,
			1,
			-(if view.later then buttonHeight + (if phone then 24 else 70) else (if phone then 12 else 50))
		),
		size = UDim2.fromOffset(buttonWidth, buttonHeight),
		zIndex = 6,
		onActivated = function()
			finish(true)
		end,
	})
	RevealStyleChips.add(nodes, view, style, styleKey, setPicked, phone, margin, buttonWidth, buttonHeight)
	if view.later then
		nodes.later = e(ToonButton, {
			variant = "secondary",
			text = view.leave,
			textSize = if phone then 18 else 36,
			sound = "back",
			anchor = Vector2.new(1, 1),
			position = UDim2.new(1, -margin, 1, -(if phone then 12 else 50)),
			size = UDim2.fromOffset(buttonWidth, math.floor(buttonHeight * 0.8)),
			zIndex = 6,
			onActivated = function()
				finish(false)
			end,
		})
	end

	-- The small picker over the reveal (an emote's wheel, or a sticker pack's spots).
	local picker: VM.Picker? = view.picker
	local itemId = reveal.ids[focus]
	if picker ~= nil and picking == styleKey and itemId ~= nil then
		local kind: VM.Picker = picker
		local context = { loadout = loadout, owns = owns, focus = focus }
		local function put(change: CosmeticTypes.Change)
			if props.reveal == nil then
				CosmeticServiceClient:requestEquip(change)
			end
		end
		nodes.picker = e(RevealSlotPicker, {
			phone = phone,
			picker = kind,
			name = view.name,
			wheel = if kind == "wheel" then VM.wheel(itemId, context) else nil,
			stickers = if kind == "stickers" then VM.stickers(itemId, context) else nil,
			onWheel = function(slot: number)
				put(VM.wheelChange(itemId, slot))
			end,
			onSticker = function(id: string, slot: number)
				put(VM.stickerChange(id, slot))
			end,
			onClose = function()
				setPicking("")
			end,
		})
	end

	local screen: Nodes = {
		confetti = if view.effects.confetti then e(RevealConfetti, { count = 34 }) else nil,
		flash = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLOR.white,
			BackgroundTransparency = flash:map(function(alpha: number): number
				return 0.15 + 0.85 * alpha
			end),
			BorderSizePixel = 0,
			ZIndex = 30,
		}),
		-- The foil: a bright diagonal band crossing the screen once.
		sweep = if view.effects.foil
			then e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = sweep:map(function(alpha: number): UDim2
					return UDim2.fromScale(-0.4 + 1.8 * alpha, 0.5)
				end),
				Size = UDim2.fromScale(0.35, 2),
				Rotation = 18,
				BackgroundColor3 = COLOR.white,
				BorderSizePixel = 0,
				ZIndex = 29,
			}, {
				gradient = e("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 0.55),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			})
			else nil,
		scaled = e(PaperHudFrame, {
			scale = scale,
			children = {
				content = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, nodes),
			},
		}),
	}
	return e(ToonBackdrop, {
		top = top,
		bottom = bottom,
		stripes = view.effects.stripes,
		rays = if view.effects.rays
			then { position = UDim2.fromScale(heroX, 0.55), size = 0.9, color = shade.hi, transparency = 0.3 }
			else nil,
		blur = props.reveal == nil,
		children = screen,
	})
end

return RevealScreen
