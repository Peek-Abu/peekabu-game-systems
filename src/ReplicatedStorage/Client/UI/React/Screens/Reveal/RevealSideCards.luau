--!strict
--[=[
	RevealSideCards: the reveal's bottom-left card. A hire gets the ID card (MORROW & MORROW, the whole new hire in
	the photo, name, job and the HIRED! stamp) and the ability card; a purchase what it does, on a cream card; a buy
	with more than one item the "YOU GOT" tiles (tapping one puts that item in front). `add` puts them into the
	screen's nodes (`idCard` and `ability`, or `also`). Split out of RevealScreen. Presentational (exempt; the values
	specced in RevealViewModel; story in RevealScreen.story).

	@class RevealSideCards
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Toon = ReplicatedStorage.Client.UI.React.Screens.Toon
local ToonButton = require(Toon.ToonButton)
local ToonIcon = require(Toon.ToonIcon)
local ToonStamp = require(Toon.ToonStamp)
local ToonSurface = require(Toon.ToonSurface)
local ToonText = require(Toon.ToonText)
local ToonViewport = require(Toon.ToonViewport)
local UIToonConstants = require(Toon.UIToonConstants)
local VM = require(script.Parent.RevealViewModel)

local e = React.createElement

local COLOR = UIToonConstants.COLOR
local DEPTH = UIToonConstants.DEPTH

type Nodes = { [string]: React.ReactNode }

-- Which item is in front, for the reveal it was tapped on.
export type Focused = { key: string, focus: number }

local RevealSideCards = {}

--[=[
	Puts the bottom-left card into `nodes`: `margin` from the left edge, `leftWidth` wide, the ID card's top at
	`heroTop`, text at `size`. A "YOU GOT" tile calls `setFocused` with the reveal's `key`.
]=]
function RevealSideCards.add(
	nodes: Nodes,
	view: VM.View,
	phone: boolean,
	size: number,
	margin: number,
	leftWidth: number,
	heroTop: number,
	key: string,
	setFocused: (focused: Focused) -> ()
)
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
	elseif view.line ~= nil then
		-- A purchase: what it does, on a cream card.
		local words: string = view.line
		local lineHeight = (size + 6) * 2
		local face: Nodes = {
			line = e(ToonText, {
				text = words,
				textSize = size + 4,
				meaning = "grape",
				position = UDim2.fromOffset(18, if phone then 12 else 20),
				size = UDim2.new(1, -36, 0, lineHeight),
				wrapped = true,
				fit = true,
			}),
		}
		nodes.also = e(ToonSurface, {
			hue = "cream",
			pattern = "rings",
			radius = 22,
			anchor = Vector2.new(0, 1),
			position = UDim2.new(0, margin, 1, -(if phone then 12 else 50)),
			size = UDim2.fromOffset(leftWidth, lineHeight + (if phone then 30 else 48)),
			zIndex = 4,
			children = face,
		})
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
end

return RevealSideCards
