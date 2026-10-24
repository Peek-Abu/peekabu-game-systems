--!strict
--[=[
	CharacterPickScreen: the first-join pick. Full screen in the selected employee's colour: the title, a column of
	employee cards (head in 3D, name, "Free!" or the hire price, the night padlock when locked), the selected employee
	LIVE on a platform with rays behind, and an About card (who they are, the five stats, the ability). The big mint
	"Start as Pippa!" sends the pick (CosmeticServiceClient:requestPick); the screen closes when the synced loadout
	says picked (DepotServiceClient takes the scene off). No close button: everyone picks once. A locked employee can
	be previewed; hiring is in the Shop (step 4). Values: CharacterPickViewModel and InventoryViewModel (layout,
	stats, colours). Exempt (wires stores; story in CharacterPickScreen.story).

	@class CharacterPickScreen
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local CosmeticServiceClient = require(ReplicatedStorage.Client.Features.Cosmetic.CosmeticServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
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
local VM = require(script.Parent.CharacterPickViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

export type CharacterPickScreenProps = {
	-- Fixed ownership instead of the store (the story).
	owns: ((id: string) -> boolean)?,
	viewport: Vector2?,
	phone: boolean?,
}

local function shadeOf(color: { body: Color3, light: Color3, dark: Color3 }): UIToonConstants.Shade
	return { base = color.body, hi = color.light, lo = color.dark }
end

local function aboutCard(employee: string, layout: InventoryViewModel.Layout, width: number): React.ReactNode
	local profile = EmployeeProfileRegistry.get(employee)
	if profile == nil then
		return nil
	end
	local phone = layout.phone
	local size = layout.textSize
	local inner = width - 36
	local face: { [string]: React.ReactNode } = {}
	local y = if phone then 10 else 18
	face.kind = e(ToonText, {
		text = string.upper(profile.kind) .. "  ·  " .. profile.line,
		textSize = size + 2,
		meaning = "grape",
		position = UDim2.fromOffset(18, y),
		size = UDim2.fromOffset(inner, size + 8),
		fit = true,
	})
	y += size + 12
	face.bio = e(ToonText, {
		text = profile.bio,
		font = "body",
		color = COLOR.ink,
		textSize = size,
		position = UDim2.fromOffset(18, y),
		size = UDim2.fromOffset(inner, size * 3),
		wrapped = true,
		fit = true,
		alignY = "top",
	})
	y += size * 3 + 6
	local row = if phone then 22 else 36
	local barX = if phone then 100 else 170
	for index, stat in InventoryViewModel.stats(employee) do
		local rowY = y + (index - 1) * row
		face[`icon{index}`] = e(ToonIcon, {
			icon = stat.icon,
			position = UDim2.fromOffset(14, rowY - 2),
			size = UDim2.fromOffset(row - 2, row - 2),
			drop = 2,
		})
		face[`label{index}`] = e(ToonText, {
			text = stat.label,
			font = "body",
			color = COLOR.ink,
			textSize = size - 2,
			position = UDim2.fromOffset(18 + row, rowY),
			size = UDim2.fromOffset(barX - row - 24, row - 6),
			fit = true,
		})
		local pipWidth = math.floor((inner - barX + 18) / 5)
		for pip = 1, 5 do
			face[`pip{index}_{pip}`] = e("Frame", {
				Position = UDim2.fromOffset(barX + (pip - 1) * pipWidth, rowY + 4),
				Size = UDim2.fromOffset(pipWidth - 6, row - 14),
				BackgroundColor3 = if pip <= stat.value then profile.color.body else UIToonConstants.shade("cream").lo,
				BorderSizePixel = 0,
			}, {
				corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 2 }),
			})
		end
	end
	y += 5 * row + 8
	local ability = profile.ability
	local abilityFace: { [string]: React.ReactNode } = {
		name = e(ToonText, {
			text = ability.name,
			textSize = size + 4,
			position = UDim2.fromOffset(14, 8),
			size = UDim2.new(1, -150, 0, size + 10),
			fit = true,
		}),
		line = e(ToonText, {
			text = ability.detail,
			font = "body",
			color = COLOR.white,
			textSize = size - 2,
			position = UDim2.fromOffset(14, size + 18),
			size = UDim2.new(1, -28, 1, -size - 26 - DEPTH.lip),
			wrapped = true,
			fit = true,
			alignY = "top",
		}),
		cooldown = e(ToonPill, {
			text = `Every {ability.cooldown}s`,
			hue = "night",
			textSize = size - 4,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -10, 0, 8),
			size = UDim2.fromOffset(if phone then 80 else 120, size + 10),
		}),
	}
	face.ability = e(ToonSurface, {
		hue = "grape",
		radius = 18,
		small = true,
		position = UDim2.fromOffset(14, y),
		size = UDim2.new(1, -28, 1, -y - 16),
		children = abilityFace,
	})
	return e(ToonSurface, {
		hue = "cream",
		pattern = "sparkle",
		radius = 24,
		size = UDim2.new(1, 0, 1, -DEPTH.drop),
		children = face,
	})
end

local function CharacterPickScreen(props: CharacterPickScreenProps): React.ReactNode
	local liveViewport = usePaperViewport()
	local livePhone = usePaperLayout() == "phone"
	local entitlements = ReactCharm.useAtom(StateSyncClientStore.entitlements)
	local selected, setSelected = React.useState(VM.DEFAULT)
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
	local listWidth = math.floor(content.width * (if phone then 0.2 else 0.18))
	local heroWidth = math.floor(content.width * 0.4)
	local aboutWidth = content.width - listWidth - heroWidth - 2 * gap
	local startHeight = if phone then 52 else 84

	-- The employee column.
	local cards = VM.cards(owns, selected)
	local cardHeight = math.min(
		if phone then 84 else 150,
		math.floor((content.height - (#cards - 1) * gap - DEPTH.drop) / math.max(1, #cards))
	)
	local column: { [string]: React.ReactNode } = {
		list = e("UIListLayout", {
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, card in cards do
		local color = InventoryViewModel.color(card.id)
		local face: { [string]: React.ReactNode } = {
			head = e(ToonViewport, {
				employee = card.id,
				framing = "head",
				dim = card.locked,
				position = UDim2.fromOffset(4, 4),
				size = UDim2.fromOffset(cardHeight - 8, cardHeight - 16),
				zIndex = 2,
			}),
			name = e(ToonText, {
				text = string.upper(card.name),
				textSize = if phone then 18 else 30,
				position = UDim2.fromOffset(cardHeight, if phone then 8 else 16),
				size = UDim2.new(1, -cardHeight - 10, 0, if phone then 22 else 36),
				fit = true,
			}),
			tag = e(ToonPill, {
				text = card.tag,
				hue = if card.locked then "night" else "mint",
				meaning = if card.locked then "gold" else nil,
				icon = if card.locked then "credits" else nil,
				textSize = if phone then 13 else 20,
				iconSize = if phone then 26 else 40,
				position = UDim2.fromOffset(cardHeight, if phone then 36 else 62),
				size = UDim2.fromOffset(if phone then 70 else 120, if phone then 24 else 36),
			}),
			lock = if card.locked
				then e(ToonIcon, {
					icon = "lockNight",
					anchor = Vector2.new(1, 0),
					position = UDim2.new(1, -6, 0, 6),
					size = UDim2.fromOffset(if phone then 22 else 36, if phone then 22 else 36),
					drop = 2,
				})
				else nil,
		}
		column[card.id] = e("TextButton", {
			Size = UDim2.new(1, 0, 0, cardHeight + DEPTH.drop),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = index,
			[React.Event.Activated] = function()
				setSelected(card.id)
			end,
		}, {
			surface = e(ToonSurface, {
				hue = "grape",
				shade = shadeOf(color),
				radius = 20,
				size = UDim2.new(1, 0, 0, cardHeight),
				children = face,
			}),
			ring = if card.selected
				then e("Frame", {
					Position = UDim2.fromOffset(-6, -6),
					Size = UDim2.new(1, 12, 0, cardHeight + 12),
					BackgroundTransparency = 1,
					ZIndex = 3,
				}, {
					corner = e("UICorner", { CornerRadius = UDim.new(0, 26) }),
					stroke = e("UIStroke", { Color = COLOR.white, Thickness = 5 }),
				})
				else nil,
		})
	end

	local tint = InventoryViewModel.color(selected)
	local start = VM.start(selected, owns)
	local selectedName = selected
	for _, card in cards do
		if card.id == selected then
			selectedName = card.name
		end
	end

	local hero: { [string]: React.ReactNode } = {
		rays = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(1.3, 1.3),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundTransparency = 1,
			Image = UIAssets.toon.rays,
			ImageColor3 = tint.light,
			ImageTransparency = 0.5,
			ZIndex = 1,
		}),
		platform = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.86),
			Size = UDim2.fromScale(0.75, 0.08),
			BackgroundColor3 = tint.dark,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke = e("UIStroke", { Color = COLOR.ink, Thickness = 4 }),
		}),
		model = e(ToonViewport, {
			employee = selected,
			live = true,
			framing = "full",
			size = UDim2.fromScale(1, 0.88),
			zIndex = 3,
		}),
		plate = e(ToonPill, {
			text = string.upper(selectedName),
			hue = "night",
			small = false,
			textSize = if phone then 22 else 40,
			anchor = Vector2.new(0.5, 1),
			position = UDim2.fromScale(0.5, 1),
			size = UDim2.fromOffset(if phone then 160 else 300, if phone then 38 else 64),
			zIndex = 4,
		}),
	}

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLOR.white,
		BorderSizePixel = 0,
		Active = true,
	}, {
		gradient = e("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(tint.body, tint.dark),
		}),
		pattern = e("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = UIAssets.toon.patternSparkle,
			ImageColor3 = COLOR.white,
			ImageTransparency = 0.9,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(96, 96),
		}),
		scaled = e(PaperHudFrame, {
			scale = scale,
			children = {
				title = e(ToonText, {
					text = "PICK YOUR EMPLOYEE!",
					textSize = layout.titleSize,
					position = UDim2.fromOffset(layout.titleX, layout.barY),
					size = UDim2.fromOffset(if phone then 360 else 700, layout.barHeight),
					fit = true,
				}),
				body = e("Frame", {
					Position = UDim2.fromOffset(content.x, content.y),
					Size = UDim2.fromOffset(content.width, content.height),
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
						Size = UDim2.new(0, aboutWidth, 1, -startHeight - gap),
						BackgroundTransparency = 1,
					}, { card = aboutCard(selected, layout, aboutWidth) }),
					start = e(ToonButton, {
						variant = "primary",
						text = start.text,
						textSize = if phone then 22 else 38,
						disabled = not start.enabled,
						sound = "cta",
						anchor = Vector2.new(1, 1),
						position = UDim2.fromScale(1, 1),
						size = UDim2.fromOffset(aboutWidth, startHeight),
						onActivated = function()
							if start.enabled and props.owns == nil then
								CosmeticServiceClient:requestPick(selected)
							end
						end,
					}),
				}),
			},
		}),
	})
end

return CharacterPickScreen
