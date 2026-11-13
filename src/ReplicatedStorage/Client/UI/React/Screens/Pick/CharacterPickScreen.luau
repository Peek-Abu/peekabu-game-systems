--!strict
--[=[
	CharacterPickScreen: the first-join pick (concept: characters/ui/character-ui/frames2/pick.jpg). On a ToonBackdrop
	in the selected employee's colour, with rays behind the hero: the big gold "PICK YOUR EMPLOYEE!" and a plate under
	it; a column of employee cards (their head breaking out of the card, name, line, "Free!" or the hire price, the
	price tag when locked: you can hire them); the selected employee LIVE on a raised platform with a two-line name plate; the About
	card (who they are, the five gold stat bars, the ability card with its render); and the big mint "Start as
	Pippa!". It sends the pick (CosmeticServiceClient:requestPick); DepotServiceClient takes the scene off when the
	synced loadout says picked. No close button: everyone picks once. A locked employee can be previewed,
	and hired here for Credits when you have enough ("Hire for 5,000", a Shop purchase). Values: CharacterPickViewModel and InventoryViewModel (layout, stats, colours). Exempt (wires stores;
	story in CharacterPickScreen.story).

	@class CharacterPickScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local CurrencyUtils = require(ReplicatedStorage.Shared.Features.Currency.Utils.CurrencyUtils)
local DealServiceClient = require(ReplicatedStorage.Client.Features.Deal.DealServiceClient)
local CosmeticServiceClient = require(ReplicatedStorage.Client.Features.Cosmetic.CosmeticServiceClient)
local ShopServiceClient = require(ReplicatedStorage.Client.Features.Shop.ShopServiceClient)
local ShopStore = require(ReplicatedStorage.Client.Features.Shop.State.ShopStore)
local ShopViewModel = require(script.Parent.Parent.Shop.ShopViewModel)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonBackdrop = require(Toon.ToonBackdrop)
local ToonButton = require(Toon.ToonButton)
local ToonFlag = require(Toon.ToonFlag)
local ToonIcon = require(Toon.ToonIcon)
local ToonCooldown = require(Toon.ToonCooldown)
local ToonPill = require(Toon.ToonPill)
local ToonPrice = require(Toon.ToonPrice)
local ToonStatRows = require(Toon.ToonStatRows)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local PaperHudFrame = require(script.Parent.Parent.Paper.PaperHudFrame)
local PaperHudScaleViewModel = require(script.Parent.Parent.Paper.PaperHudScaleViewModel)
local usePaperLayout = require(script.Parent.Parent.Paper.usePaperLayout)
local usePaperViewport = require(script.Parent.Parent.Paper.usePaperViewport)
local InventoryViewModel = require(script.Parent.Parent.Inventory.InventoryViewModel)
local DealViewModel = require(script.Parent.Parent.Deal.DealViewModel)
local VM = require(script.Parent.CharacterPickViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }
type Tint = { body: Color3, light: Color3, dark: Color3 }

export type CharacterPickScreenProps = {
	-- Fixed ownership instead of the store (the story).
	owns: ((id: string) -> boolean)?,
	viewport: Vector2?,
	phone: boolean?,
}

local function shadeOf(color: Tint): UIToonConstants.Shade
	return { base = color.body, hi = color.light, lo = color.dark }
end

local function card(
	entry: VM.Card,
	height: number,
	phone: boolean,
	order: number,
	onSelect: (id: string) -> ()
): React.ReactNode
	local color = InventoryViewModel.color(entry.id)
	local profile = EmployeeProfileRegistry.get(entry.id)
	local head = math.floor(height * 1.15)
	local nameSize = math.floor(height * 0.34)
	local face: Nodes = {
		name = e(ToonText, {
			text = string.upper(entry.name),
			textSize = nameSize,
			position = UDim2.fromOffset(math.floor(head * 0.78), math.floor(height * 0.12)),
			size = UDim2.new(1, -math.floor(head * 0.78) - 12, 0, nameSize + 6),
			fit = true,
		}),
	}
	if entry.locked then
		local price: Nodes = {
			price = e(ToonPrice, {
				currency = "credits",
				amount = entry.tag,
				textSize = math.floor(height * 0.2),
				align = "center",
				size = UDim2.new(1, 0, 1, -4),
			}),
		}
		face.price = e(ToonSurface, {
			hue = "night",
			radius = 999,
			small = true,
			position = UDim2.fromOffset(math.floor(head * 0.78), math.floor(height * 0.52)),
			size = UDim2.fromOffset(math.floor(height * 1.2), math.floor(height * 0.32)),
			children = price,
		})
	elseif profile ~= nil then
		face.line = e(ToonText, {
			text = profile.line,
			font = "body",
			color = COLOR.white,
			textSize = math.max(if phone then 12 else 18, math.floor(height * 0.15)),
			position = UDim2.fromOffset(math.floor(head * 0.78), math.floor(height * 0.52)),
			size = UDim2.new(1, -math.floor(head * 0.78) - 12, 0, math.floor(height * 0.2)),
			fit = true,
		})
	end
	local nodes: Nodes = {
		surface = e(ToonSurface, {
			hue = "grape",
			shade = shadeOf(color),
			radius = 22,
			position = UDim2.fromOffset(0, math.floor(height * 0.18)),
			size = UDim2.new(1, 0, 0, height),
			children = face,
			zIndex = 2,
		}),
		-- The head breaks out of the card's top-left.
		head = e(ToonViewport, {
			employee = entry.id,
			framing = "upper",
			dim = entry.locked,
			position = UDim2.fromOffset(-math.floor(head * 0.06), 0),
			size = UDim2.fromOffset(head, head),
			zIndex = 3,
		}),
	}
	if entry.selected then
		nodes.ring = e("Frame", {
			Position = UDim2.fromOffset(-8, math.floor(height * 0.18) - 8),
			Size = UDim2.new(1, 16, 0, height + DEPTH.drop + 16),
			BackgroundTransparency = 1,
			ZIndex = 1,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0, 30) }),
			stroke = e("UIStroke", { Color = COLOR.selected, Thickness = 6 }),
		})
	end
	if entry.locked then
		local lock = math.floor(height * 0.42)
		nodes.lock = e(ToonIcon, {
			icon = "priceTag",
			position = UDim2.fromOffset(0, math.floor(height * 0.18)),
			size = UDim2.fromOffset(lock, lock),
			drop = 3,
			zIndex = 4,
		})
	else
		nodes.free = e(ToonFlag, {
			text = entry.tag,
			hue = "mint",
			tilt = 8,
			textSize = if phone then 13 else 22,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, 10, 0, math.floor(height * 0.08)),
			size = UDim2.fromOffset(if phone then 64 else 104, if phone then 24 else 38),
			zIndex = 4,
		})
	end
	return e("TextButton", {
		Size = UDim2.new(1, 0, 0, math.floor(height * 1.18) + DEPTH.drop),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		[React.Event.Activated] = function()
			onSelect(entry.id)
		end,
	}, nodes)
end

local function aboutCard(employee: string, layout: InventoryViewModel.Layout, height: number): React.ReactNode
	local profile = EmployeeProfileRegistry.get(employee)
	if profile == nil then
		return nil
	end
	local phone = layout.phone
	local size = layout.textSize
	local face: Nodes = {}
	local y = if phone then 10 else 20
	face.title = e(ToonText, {
		text = `ABOUT {string.upper(employee)}`,
		textSize = size + 10,
		position = UDim2.fromOffset(20, y),
		size = UDim2.new(1, -40, 0, size + 14),
		fit = true,
	})
	y += size + 18
	face.bio = e(ToonText, {
		text = profile.bio,
		font = "body",
		color = COLOR.white,
		textSize = size,
		position = UDim2.fromOffset(20, y),
		size = UDim2.new(1, -40, 0, size * 3),
		wrapped = true,
		fit = true,
		alignY = "top",
	})
	y += size * 3 + 8
	local abilityHeight = if phone then 64 else 120
	local row = math.clamp(
		math.floor((height - y - abilityHeight - 30 - DEPTH.drop) / 5),
		if phone then 18 else 30,
		if phone then 26 else 54
	)
	local barX = if phone then 110 else 200
	face.stats = e(ToonStatRows, {
		rows = InventoryViewModel.stats(employee),
		row = row,
		barX = barX + 4,
		textSize = size,
		position = UDim2.fromOffset(16, y),
		size = UDim2.new(1, -36, 0, row * 5),
	})
	-- The ability card at the foot, its render breaking the left edge, the cooldown on a round chip.
	local art = math.floor(abilityHeight * 1.05)
	local ability: Nodes = {
		name = e(ToonText, {
			text = profile.ability.name,
			textSize = size + 10,
			position = UDim2.fromOffset(math.floor(art * 0.7), 8),
			size = UDim2.new(1, -math.floor(art * 0.7) - 90, 0, size + 14),
			fit = true,
		}),
		line = e(ToonText, {
			text = profile.ability.line,
			font = "body",
			color = COLOR.white,
			textSize = size - 2,
			position = UDim2.fromOffset(math.floor(art * 0.7), size + 24),
			size = UDim2.new(1, -math.floor(art * 0.7) - 90, 0, size + 4),
			fit = true,
		}),
		cooldown = e(ToonCooldown, {
			seconds = profile.ability.cooldown,
			height = if phone then 46 else 72,
			anchor = Vector2.new(1, 0.5),
			position = UDim2.new(1, -14, 0.5, -2),
			size = UDim2.fromOffset(if phone then 56 else 84, if phone then 46 else 72),
		}),
	}
	face.ability = e(ToonSurface, {
		hue = "grape",
		radius = 20,
		position = UDim2.fromOffset(16 + math.floor(art * 0.3), height - abilityHeight - 22 - DEPTH.drop),
		size = UDim2.new(1, -32 - math.floor(art * 0.3), 0, abilityHeight),
		children = ability,
	})
	face.abilityArt = e(ToonIcon, {
		image = UIAssets.iconImage(profile.ability.icon),
		anchor = Vector2.new(0, 0.5),
		position = UDim2.fromOffset(4, height - abilityHeight / 2 - 26 - DEPTH.drop),
		size = UDim2.fromOffset(art, art),
		drop = 4,
		zIndex = 3,
	})
	return e(ToonSurface, {
		hue = "lilac",
		shade = {
			base = UIToonConstants.shade("grape").lo,
			hi = UIToonConstants.shade("grape").base,
			lo = UIToonConstants.shade("night").base,
		},
		pattern = "bubbles",
		radius = 28,
		size = UDim2.new(1, 0, 1, -DEPTH.drop),
		children = face,
	})
end

local function CharacterPickScreen(props: CharacterPickScreenProps): React.ReactNode
	local liveViewport = usePaperViewport()
	local livePhone = usePaperLayout() == "phone"
	local entitlements = ReactCharm.useAtom(StateSyncClientStore.entitlements)
	local currency = ReactCharm.useAtom(StateSyncClientStore.currency)
	local premium = ReactCharm.useAtom(StateSyncClientStore.premium)
	-- "Hire with 30 Gleam" was tapped once for this employee ("" none): the next tap spends.
	local sureOf, setSureOf = React.useState("")
	local buyResult = ReactCharm.useAtom(ShopStore.result)
	local deals = ReactCharm.useAtom(StateSyncClientStore.deals)
	local selected, setSelected = React.useState(VM.DEFAULT)
	local noClick: number? = nil
	local clickedAt, setClickedAt = React.useState(noClick)
	local buyNote = if props.owns == nil
			and buyResult ~= nil
			and buyResult.offer == selected
		then ShopViewModel.resultText(buyResult.reason)
		else nil
	local owns = props.owns or function(id: string): boolean
		return CosmeticRules.owns(entitlements, id)
	end

	local viewport = props.viewport or liveViewport
	local phone = if props.phone ~= nil then props.phone else livePhone
	local scale = PaperHudScaleViewModel.scale(viewport, if phone then "phone" else "desktop")
	local virtual =
		PaperHudScaleViewModel.virtual(viewport - Vector2.new(0, PaperHudScaleViewModel.topShift(scale)), scale)
	local layout = InventoryViewModel.layout(virtual, phone)
	local content = layout.content
	local gap = layout.gap
	local titleSize = if phone then 44 else 104
	local top = layout.barY + titleSize + (if phone then 30 else 58)
	local height = math.max(0, virtual.Y - top - (if phone then 12 else 24))
	local listWidth = math.floor(content.width * (if phone then 0.26 else 0.25))
	local heroWidth = math.floor(content.width * (if phone then 0.36 else 0.4))
	local aboutWidth = content.width - listWidth - heroWidth - 2 * gap
	local startHeight = if phone then 52 else 96

	-- The employee column.
	local cards = VM.cards(owns, selected)
	local cardHeight = math.min(
		if phone then 64 else 150,
		math.floor((height - (#cards - 1) * gap) / math.max(1, #cards) / 1.18 - DEPTH.drop)
	)
	local column: Nodes = {
		list = e("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }),
		pad = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	}
	local selectedName = selected
	for index, entry in cards do
		column[entry.id] = card(entry, cardHeight, phone, index, function(id: string)
			setSelected(id)
			setClickedAt(os.clock())
		end)
		if entry.id == selected then
			selectedName = entry.name
		end
	end

	local tint = InventoryViewModel.color(selected)
	local profile = EmployeeProfileRegistry.get(selected)
	local start = VM.start(
		selected,
		owns,
		CurrencyUtils.getCurrencyAmount(currency, "credits"),
		if props.owns == nil then premium.balance else 0,
		sureOf == selected
	)
	-- Pick a New Hire for a locked employee: hire them now with their Legendary skin (a Robux deal, once).
	local dealText = if props.owns == nil
		then DealViewModel.hireButton(selected, owns, deals, DealServiceClient:productReady("pickNewHire"))
		else nil
	local dealHeight = if phone then 40 else 76
	local plateHeight = if phone then 44 else 104
	local plate: Nodes = {
		name = e(ToonText, {
			text = string.upper(selectedName),
			textSize = if phone then 22 else 56,
			position = UDim2.fromOffset(0, if phone then 2 else 6),
			size = UDim2.new(1, 0, 0, if phone then 24 else 60),
			align = "center",
			fit = true,
		}),
		line = if profile ~= nil
			then e(ToonText, {
				text = `{profile.kind} · {profile.line}`,
				font = "body",
				color = COLOR.white,
				textSize = if phone then 12 else 24,
				position = UDim2.fromOffset(10, if phone then 24 else 64),
				size = UDim2.new(1, -20, 0, if phone then 14 else 28),
				align = "center",
				fit = true,
			})
			else nil,
	}
	local hero: Nodes = {
		model = e(ToonViewport, {
			employee = selected,
			live = true,
			react = clickedAt,
			framing = "full",
			platform = { top = tint.body, side = tint.dark },
			size = UDim2.fromScale(1, 0.84),
			zIndex = 3,
		}),
		plate = e(ToonSurface, {
			hue = "grape",
			radius = 22,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.fromScale(0.5, 1),
			size = UDim2.fromOffset(if phone then 180 else 380, plateHeight),
			zIndex = 4,
			children = plate,
		}),
	}

	local heroX = (content.x + listWidth + gap + heroWidth / 2) / math.max(1, virtual.X)
	local screen: Nodes = {
		scaled = e(PaperHudFrame, {
			scale = scale,
			children = {
				title = e(ToonText, {
					text = "PICK YOUR EMPLOYEE!",
					textSize = titleSize,
					meaning = "gold",
					rotation = -2,
					anchor = Vector2.new(0.5, 0),
					position = UDim2.new(0.5, 0, 0, layout.barY),
					size = UDim2.fromOffset(math.floor(virtual.X * 0.62), titleSize + 12),
					align = "center",
					fit = true,
				}),
				sub = e(ToonPill, {
					text = "You can switch any time in your Inventory at the depot",
					hue = "night",
					textSize = if phone then 13 else 22,
					padX = 24,
					anchor = Vector2.new(0.5, 0),
					position = UDim2.new(0.5, 0, 0, layout.barY + titleSize + (if phone then 4 else 8)),
					size = UDim2.fromOffset(if phone then 420 else 820, if phone then 26 else 48),
				}),
				body = e("Frame", {
					Position = UDim2.fromOffset(content.x, top),
					Size = UDim2.fromOffset(content.width, height),
					BackgroundTransparency = 1,
				}, {
					column = e("Frame", {
						Size = UDim2.new(0, listWidth, 1, 0),
						BackgroundTransparency = 1,
					}, column),
					hero = e("Frame", {
						Position = UDim2.fromOffset(listWidth + gap, 0),
						Size = UDim2.new(0, heroWidth, 1, 0),
						BackgroundTransparency = 1,
					}, hero),
					about = e("Frame", {
						Position = UDim2.fromOffset(listWidth + heroWidth + 2 * gap, 0),
						Size = UDim2.new(
							0,
							aboutWidth,
							1,
							-startHeight - gap - (if dealText ~= nil then dealHeight + gap else 0)
						),
						BackgroundTransparency = 1,
					}, {
						card = aboutCard(
							selected,
							layout,
							height - startHeight - gap - (if dealText ~= nil then dealHeight + gap else 0)
						),
					}),
					deal = if dealText ~= nil
						then e(ToonButton, {
							variant = "gleam",
							text = dealText,
							textSize = if phone then 18 else 36,
							sound = "cta",
							anchor = Vector2.new(1, 1),
							position = UDim2.new(1, 0, 1, -startHeight - gap),
							size = UDim2.fromOffset(aboutWidth, dealHeight),
							onActivated = function()
								DealServiceClient:buy("pickNewHire", selected)
							end,
						})
						else nil,
					note = if buyNote ~= nil
						then e(ToonText, {
							text = buyNote,
							textSize = layout.textSize,
							meaning = "white",
							anchor = Vector2.new(1, 1),
							position = UDim2.new(1, 0, 1, -startHeight - 4),
							size = UDim2.fromOffset(aboutWidth, layout.textSize + 8),
							fit = true,
							align = "center",
						})
						else nil,
					start = e(ToonButton, {
						variant = "primary",
						text = start.text,
						textSize = if phone then 22 else 46,
						disabled = not start.enabled,
						sound = "cta",
						anchor = Vector2.new(1, 1),
						position = UDim2.fromScale(1, 1),
						size = UDim2.fromOffset(aboutWidth, startHeight),
						onActivated = function()
							if not start.enabled or props.owns ~= nil then
								return
							end
							if start.kind == "topup" then
								-- Gleam pays the rest: the first tap asks, the second spends.
								if sureOf ~= selected then
									setSureOf(selected)
								else
									setSureOf("")
									ShopServiceClient:requestBuy(selected, start.gleam)
								end
							elseif start.kind == "hire" then
								-- Hiring is a Shop purchase; once it lands the button says Start.
								ShopServiceClient:requestBuy(selected)
							else
								CosmeticServiceClient:requestPick(selected)
							end
						end,
					}),
				}),
			},
		}),
	}
	return e(ToonBackdrop, {
		top = tint.body,
		bottom = tint.dark,
		rays = { position = UDim2.fromScale(heroX, 0.55), size = 0.75, color = tint.light, transparency = 0.35 },
		children = screen,
	})
end

return CharacterPickScreen
