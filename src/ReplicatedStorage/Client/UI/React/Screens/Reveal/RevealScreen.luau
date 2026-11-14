--!strict
--[=[
	RevealScreen: "you got it!" after a purchase, a grant or the first-join pick (concepts:
	characters/ui/character-ui/frames4/reveal-leg.jpg and reveal-hire.jpg). On a ToonBackdrop in the rarity's colour
	(rays from Rare, stripes from Epic, confetti for Legendary): the title popping in ("LEGENDARY!"), a ribbon ("New
	skin for Pippa"), the item LIVE on a raised platform with its name plate, and the buttons (the main one's words fit
	the item: Wear it!, Use it!, Add to wheel!, Use stickers!; Later, or Nice!). A buy with more than one item shows a
	"YOU GOT" tile for each: tapping one puts it in front with its own button, the screen stays open after using one,
	and Done leaves. An emote's Add to wheel! and a sticker pack's Use stickers! open the Inventory over it at that
	item's picker (UIStore.inventoryAt); closing the Inventory comes back here. A hire shows the ID card stamped HIRED!, the ability card and Start! or Equip!. Reads
	CosmeticRevealStore.current (one at a time); a button moves the queue on, and the main button sends the changes
	through CosmeticServiceClient. Values are RevealViewModel's. Exempt (wires stores; story in RevealScreen.story).

	@class RevealScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticOutfitRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticOutfitRules)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local CosmeticServiceClient = require(ReplicatedStorage.Client.Features.Cosmetic.CosmeticServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local CosmeticRevealStore = require(ReplicatedStorage.Client.Features.Cosmetic.State.CosmeticRevealStore)
local SceneStack = require(ReplicatedStorage.Client.UI.Scenes.SceneStack)
local UIStore = require(ReplicatedStorage.Client.UI.Scenes.UIStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBackdrop = require(Toon.ToonBackdrop)
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonSparkle = require(Toon.ToonSparkle)
local ToonStamp = require(Toon.ToonStamp)
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

local CONFETTI_COLORS = {
	Color3.fromHex("FFC93A"),
	Color3.fromHex("33E8A9"),
	Color3.fromHex("FF4F6E"),
	Color3.fromHex("5CC8FF"),
	Color3.fromHex("B48BFF"),
}

-- Confetti falling for good: each piece has its own column, speed, start and sway, driven by one looping clock (a
-- fixed pattern, the same every time; still under Reduce Motion).
local FALL_SECONDS = 6

local function Confetti(props: { count: number }): React.ReactNode
	local clock = useToonPlay(FALL_SECONDS, 0, nil, true)
	local nodes: Nodes = {}
	local state = 7
	local function nextNumber(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	for index = 1, props.count do
		local x = nextNumber()
		local start = nextNumber()
		local speed = 1 + math.floor(nextNumber() * 2)
		local spin = math.floor(nextNumber() * 360)
		nodes[`c{index}`] = e("Frame", {
			Position = clock:map(function(alpha: number): UDim2
				local fall = (start + alpha * speed) % 1
				return UDim2.fromScale(x + 0.02 * math.sin((alpha * speed + start) * math.pi * 4), fall * 1.1 - 0.05)
			end),
			Rotation = clock:map(function(alpha: number): number
				return spin + alpha * 360 * speed
			end),
			Size = UDim2.fromOffset(14, 26),
			BackgroundColor3 = CONFETTI_COLORS[index % #CONFETTI_COLORS + 1],
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 3 }),
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, nodes)
end

-- A colour style chip's face: its two colours (the fur, then the outfit) as dots, then its name.
local function chipFace(chip: VM.StyleChip, size: number): Nodes
	local dot = size - 2
	local face: Nodes = {
		name = e(ToonText, {
			text = chip.name,
			textSize = size - 4,
			meaning = "grape",
			position = UDim2.fromOffset(dot * 2 + 14, 0),
			size = UDim2.new(1, -(dot * 2 + 18), 1, 0),
			fit = true,
		}),
	}
	for index, colour in chip.swatch do
		face[`dot{index}`] = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6 + (index - 1) * (dot + 2), 0.5, 0),
			Size = UDim2.fromOffset(dot, dot),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
		}, {
			round = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			edge = e("UIStroke", { Color = COLOR.ink, Thickness = 2 }),
		})
	end
	return face
end

local function RevealScreen(props: RevealScreenProps): React.ReactNode
	local liveViewport = usePaperViewport()
	local livePhone = usePaperLayout() == "phone"
	local stored = ReactCharm.useAtom(CosmeticRevealStore.current)
	local loadout = ReactCharm.useAtom(StateSyncClientStore.loadout)
	local entitlements = ReactCharm.useAtom(StateSyncClientStore.entitlements)
	local reveal = props.reveal or stored
	local noScale: UIScale? = nil
	local pop, setPop = React.useState(noScale)

	local key = if reveal ~= nil then table.concat(reveal.ids, ",") else ""
	-- Which item is in front (a buy with more than one), for the reveal it was tapped on (a new reveal starts at 1).
	local focused, setFocused = React.useState({ key = "", focus = 1 })
	local focus = if focused.key == key then focused.focus else 1
	-- The colour style picked to wear, for the item it was picked on (a new one starts at style 1).
	local styleKey = `{key}#{focus}`
	local picked, setPicked = React.useState({ key = "", style = 1 })
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
		local opens = view.opens
		if equip and opens ~= nil then
			-- An emote or a sticker pack: the Inventory's own picker opens over the reveal; closing it comes back here.
			UIStore.inventoryAt(opens)
			SceneStack.push(InventoryViewModel.SCENE)
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
		-- A sticker pack shows its stickers; anything else the model.
		model = if view.stickers
			then e(ToonIcon, {
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
	if view.kind == "hire" then
		local cardHeight = if phone then 120 else 300
		local photo = math.floor(cardHeight * 0.66)
		-- The ID photo shows the whole new hire, ears to feet, in a frame taller than wide (owner, 2026-11-12: a hire is
		-- never cut off; a bust cut Pippa's ear tips and legs).
		local photoTop = if phone then 30 else 64
		local photoWidth = math.floor(photo * 0.78)
		local photoHeight = cardHeight - photoTop - (if phone then 8 else 18)
		local card: Nodes = {
			header = e(ToonText, {
				text = "MORROW & MORROW",
				textSize = if phone then 15 else 34,
				meaning = "grape",
				position = UDim2.fromOffset(16, 8),
				size = UDim2.new(1, -32, 0, if phone then 18 else 40),
				fit = true,
			}),
			photo = e(ToonViewport, {
				employee = view.employee,
				framing = "full",
				position = UDim2.fromOffset(14, photoTop),
				size = UDim2.fromOffset(photoWidth, photoHeight),
			}),
			name = e(ToonText, {
				text = `Name: {view.name}`,
				font = "body",
				color = COLOR.ink,
				textSize = size + 2,
				position = UDim2.fromOffset(photoWidth + 26, if phone then 34 else 76),
				size = UDim2.new(1, -photoWidth - 40, 0, size + 6),
				fit = true,
			}),
			job = e(ToonText, {
				text = `Job: {view.job}`,
				font = "body",
				color = COLOR.ink,
				textSize = size + 2,
				position = UDim2.fromOffset(photoWidth + 26, if phone then 56 else 124),
				size = UDim2.new(1, -photoWidth - 40, 0, size + 6),
				fit = true,
			}),
			stamp = e(ToonStamp, {
				text = "HIRED!",
				size = if phone then 70 else 170,
				hue = "mint",
				anchor = Vector2.new(1, 1),
				position = UDim2.new(1, -10, 1, -6),
				zIndex = 5,
			}),
		}
		nodes.idCard = e(ToonSurface, {
			hue = "cream",
			radius = 22,
			position = UDim2.fromOffset(margin, heroTop),
			size = UDim2.fromOffset(leftWidth, cardHeight),
			zIndex = 4,
			children = card,
		})
		local ability = view.ability
		if ability ~= nil then
			local abilityHeight = if phone then 60 else 130
			local art = math.floor(abilityHeight * 1.05)
			local face: Nodes = {
				name = e(ToonText, {
					text = ability.name,
					textSize = size + 10,
					position = UDim2.fromOffset(math.floor(art * 0.72), 10),
					size = UDim2.new(1, -math.floor(art * 0.72) - 14, 0, size + 14),
					fit = true,
				}),
				line = e(ToonText, {
					text = ability.line,
					font = "body",
					color = COLOR.white,
					textSize = size,
					position = UDim2.fromOffset(math.floor(art * 0.72), size + 28),
					size = UDim2.new(1, -math.floor(art * 0.72) - 14, 0, size + 4),
					fit = true,
				}),
			}
			nodes.ability = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, margin, 1, -(if phone then 12 else 50)),
				Size = UDim2.fromOffset(leftWidth, abilityHeight),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, {
				card = e(ToonSurface, {
					hue = "grape",
					radius = 20,
					position = UDim2.fromOffset(math.floor(art * 0.3), 0),
					size = UDim2.new(1, -math.floor(art * 0.3), 1, -DEPTH.drop),
					children = face,
				}),
				art = e(ToonIcon, {
					image = ability.image,
					anchor = Vector2.new(0, 0.5),
					position = UDim2.new(0, -8, 0.5, -4),
					size = UDim2.fromOffset(art, art),
					drop = 4,
					zIndex = 3,
				}),
			})
		end
	elseif view.multi then
		local tile = if phone then 44 else 96
		local tiles: Nodes = {
			list = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index, extra in view.items do
			local stage: { [string]: React.ReactNode } = {
				art = if extra.kind == "Sticker pack"
					then e(ToonIcon, {
						icon = "stickers",
						position = UDim2.fromScale(0.08, 0.08),
						size = UDim2.fromScale(0.84, 0.84),
					})
					else e(ToonViewport, {
						employee = view.employee,
						skin = extra.skinKey,
						framing = "bust",
						size = UDim2.fromScale(1, 1),
					}),
			}
			local label = if phone then 11 else 18
			-- The tile is a button (tap it to put that item in front); its kind under it, and "on" once it is on
			-- (never over the picture).
			tiles[extra.id] = e("Frame", {
				Size = UDim2.fromOffset(tile + 20, tile + DEPTH.drop + label + 10),
				BackgroundTransparency = 1,
				LayoutOrder = index,
			}, {
				tile = e(ToonButton, {
					variant = "secondary",
					selected = extra.selected,
					content = stage,
					position = UDim2.fromOffset(10, 0),
					size = UDim2.fromOffset(tile, tile),
					radius = 14,
					onActivated = function()
						setFocused({ key = key, focus = index })
					end,
				}),
				kind = e(ToonText, {
					text = if extra.done then `{extra.kind}: on` else extra.kind,
					textSize = label,
					meaning = if extra.done then "mint" else "grape",
					anchor = Vector2.new(0.5, 0),
					-- Under the tile's hard drop, so the drop never covers the word.
					position = UDim2.new(0.5, 0, 0, tile + DEPTH.drop + 4),
					size = UDim2.new(1, 0, 0, label + 4),
					align = "center",
					fit = true,
				}),
			})
		end
		local face: Nodes = {
			title = e(ToonText, {
				text = "YOU GOT",
				textSize = size + 6,
				meaning = "grape",
				position = UDim2.fromOffset(18, 12),
				size = UDim2.new(1, -36, 0, size + 10),
				fit = true,
			}),
			row = e("Frame", {
				-- Clear of the title, with room for the picked tile's ring.
				Position = UDim2.fromOffset(18, size + 40),
				Size = UDim2.new(1, -36, 0, tile + DEPTH.drop + (if phone then 22 else 34)),
				BackgroundTransparency = 1,
			}, tiles),
		}
		nodes.also = e(ToonSurface, {
			hue = "cream",
			pattern = "rings",
			radius = 22,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, margin, 1, -(if phone then 12 else 50)),
			size = UDim2.fromOffset(leftWidth, size + tile + DEPTH.drop + (if phone then 76 else 120)),
			zIndex = 4,
			children = face,
		})
	end

	-- Bottom right: the buttons.
	local buttonWidth = math.floor(virtual.X * (if phone then 0.26 else 0.2))
	local buttonHeight = if phone then 46 else 96
	nodes.primary = e(ToonButton, {
		variant = "primary",
		text = view.primary,
		-- Already on, or nothing to put on while the screen stays open: greyed (Done leaves).
		disabled = view.done or (view.stays and #view.changes == 0 and view.opens == nil),
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
	-- A new skin with colour styles: a chip per style above the buttons; the pick shows on the hero and Wear it! puts
	-- it on.
	local chips = view.styles
	if #chips > 0 then
		local chipSize = if phone then 14 else 26
		local chipHeight = chipSize + 22
		local rowWidth = math.floor(buttonWidth * 1.6)
		local chipWidth = math.floor((rowWidth - (#chips - 1) * 10) / #chips)
		local above = (if view.later then buttonHeight + (if phone then 24 else 70) else (if phone then 12 else 50))
			+ buttonHeight
			+ (if phone then 12 else 24)
		local row: Nodes = {}
		for index, chip in chips do
			row[`style{index}`] = e(ToonButton, {
				variant = "secondary",
				selected = index == style,
				content = chipFace(chip, chipSize),
				position = UDim2.fromOffset((index - 1) * (chipWidth + 10), 0),
				size = UDim2.fromOffset(chipWidth, chipHeight),
				zIndex = 6,
				onActivated = function()
					setPicked({ key = styleKey, style = index })
				end,
			})
		end
		nodes.styles = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -margin, 1, -above),
			Size = UDim2.fromOffset(rowWidth, chipHeight),
			BackgroundTransparency = 1,
			ZIndex = 6,
		}, row)
	end
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

	local screen: Nodes = {
		confetti = if view.effects.confetti then e(Confetti, { count = 34 }) else nil,
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
