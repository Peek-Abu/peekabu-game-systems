--!strict
--[=[
	InventoryViewModel: everything the Inventory screens show, worked out from the catalogue (CosmeticRegistry), the
	employee profiles (EmployeeProfileRegistry), the player's loadout and what they own. Nothing here is per
	character: a new employee or skin in the registries shows up on every screen by itself.

	- `crew`: one card per employee (free ones first): the skin they wear, and whether they are worn, owned or locked.
	- `items`: an employee's skins or idles as grid cards (the free one first, then by rarity) with their footer band.
	- `band` / `action`: where a locked item comes from (the card's footer) and the detail panel's main button.
	- `detail`: the right-hand panel for the selected item (flags, lore, Styles row, Comes with, button).
	  (`items`, `band`, `action` and `detail` live in InventoryItemViewModel, split out of this file; re-exported here.)
	- `change`: the CosmeticServiceClient change Wear sends.
	- `stats`: the About tab's five stat rows.

	@class InventoryViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetic = ReplicatedStorage.Shared.Features.Cosmetic
local CosmeticRegistry = require(Cosmetic.Data.CosmeticRegistry)
local CosmeticRules = require(Cosmetic.Rules.CosmeticRules)
local CosmeticTypes = require(Cosmetic.Data.CosmeticTypes)
local CalloutAssets = require(ReplicatedStorage.Client.Features.Callout.Data.CalloutAssets)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonStatRows = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStatRows)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local ToonMenuBarViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonMenuBarViewModel)
local InventoryItemViewModel = require(script.Parent.InventoryItemViewModel)

type Item = CosmeticTypes.Item
type Loadout = CosmeticTypes.Loadout
type Owns = (id: string) -> boolean

export type Band = InventoryItemViewModel.Band
export type Action = InventoryItemViewModel.Action
export type Bundled = InventoryItemViewModel.Bundled
export type ItemCard = InventoryItemViewModel.ItemCard
export type StyleChip = InventoryItemViewModel.StyleChip
export type Detail = InventoryItemViewModel.Detail
export type WheelSlot = InventoryItemViewModel.WheelSlot
export type ListKind = InventoryItemViewModel.ListKind
export type CrewState = "wearing" | "owned" | "locked"

export type CrewCard = {
	id: string,
	name: string,
	-- "Bunny", "Cactus".
	kind: string,
	line: string,
	ability: string,
	state: CrewState,
	price: number?,
	priceText: string?,
	-- The ability's render (UIAssets image id), nil when the profile names none the kit has.
	abilityImage: string?,
	-- The worn skin: its catalogue name and its EmployeeRegistry art key (the part after the dot).
	skinName: string,
	skinKey: string,
	color: { body: Color3, light: Color3, dark: Color3 },
}

-- A row of cards on a page tab, with its heading (nil = none).
export type Section = { title: string?, cards: { ItemCard } }

-- The Chat wheel tab: the player's 4 sticker slots and every sticker pack (owned ones list their stickers).
export type StickerSlot = { slot: number, id: string?, name: string, image: string?, empty: boolean }
export type Sticker = { id: string, name: string, image: string }
export type Pack = {
	id: string,
	name: string,
	rarity: CosmeticTypes.Rarity,
	owned: boolean,
	price: string?,
	stickers: { Sticker },
}
export type ChatView = { slots: { StickerSlot }, packs: { Pack } }

-- One stat's row, in the shape ToonStatRows draws (its render, its name, its short line, its 1-5 value).
export type StatRow = ToonStatRows.ToonStatRow
export type Tab = { id: string, text: string, soon: boolean, icon: UIAssets.ToonIcon? }
-- An employee page's tabs. Vacuum skins are skins: they sit in a row of their own on the Skins tab (owner,
-- 2026-11-13; the old Vacuums tab is gone).
export type PageTab = "skins" | "emotes" | "idles" | "about"
-- Design px against the virtual screen (PaperHudScaleViewModel.virtual).
export type Layout = {
	phone: boolean,
	barY: number,
	barHeight: number,
	-- Where the title starts: clear of Roblox's own top-left buttons.
	titleX: number,
	titleSize: number,
	-- The area under the bar.
	content: { x: number, y: number, width: number, height: number },
	crewCard: Vector2,
	-- The Crew row's room above the cards (their tilted flags) and below them (the wearing ring's overhang and the
	-- scroll bar), px.
	crewPad: { top: number, bottom: number },
	gap: number,
	-- The character page (its tabs are in the menu bar): grid | hero | detail.
	gridWidth: number,
	heroWidth: number,
	detailWidth: number,
	cell: Vector2,
	textSize: number,
	headingSize: number,
}

local STAT_LABEL: { [EmployeeProfileRegistry.Stat]: string } = {
	speed = "Speed",
	stamina = "Stamina",
	strength = "Strength",
	suction = "Suction",
	quiet = "Quiet",
}

-- What each stat does, in one short line (kid reading level; the design's approved words). Quiet is about every map's
-- monster, not one.
local STAT_HINT: { [EmployeeProfileRegistry.Stat]: string } = {
	speed = "Run faster.",
	stamina = "Run longer.",
	strength = "Carry big stuff faster.",
	suction = "Clean faster.",
	quiet = "Monsters hear you less.",
}

local STAT_ICON: { [EmployeeProfileRegistry.Stat]: UIAssets.ToonIcon } = {
	speed = "statSpeed",
	stamina = "statStamina",
	strength = "statStrength",
	suction = "statSuction",
	quiet = "statQuiet",
}

local PLAIN = Color3.fromRGB(183, 164, 236)

local VM = {}

VM.SCENE = "inventory"

local PAGE_TABS: { PageTab } = { "skins", "emotes", "idles", "about" }
VM.PAGE_TABS = table.freeze(PAGE_TABS)

-- The EmployeeRegistry art key of a skin id ("Pippa.OwnerSpecial" -> "OwnerSpecial").
function VM.skinKey(id: string): string
	return string.match(id, "^[^%.]+%.(.+)$") or id
end

export type TagFrame = { anchor: Vector2, position: UDim2, size: number }

--[=[
	Where a locked employee's hire tag hangs on its Crew card (owner pick 2026-11-15, Option 2): the card's top-right
	corner, where the wearer's "You!" flag sits (anchor top-right, 14 px past the edge), never over the portrait.
	`size` is the square tag's side (design px).
]=]
function VM.crewTagFrame(phone: boolean): TagFrame
	return {
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 14, 0, 0),
		-- The size the owner picked from (Studio mock 11-15): about the You! flag's height.
		size = if phone then 50 else 76,
	}
end

-- The mark on a locked item card: a price tag when its band is a price (you can buy it), else the lock (owner pick
-- 2026-11-13: the price tag only on what you can buy).
function VM.lockIcon(card: { band: Band? }): UIAssets.ToonIcon
	local band = card.band
	if band ~= nil and (band.kind == "credits" or band.kind == "gleam") then
		return "priceTag"
	end
	return "lockNight"
end

VM.band = InventoryItemViewModel.band
VM.action = InventoryItemViewModel.action

local function colorOf(employee: string): { body: Color3, light: Color3, dark: Color3 }
	local profile = EmployeeProfileRegistry.get(employee)
	return if profile ~= nil then profile.color else { body = PLAIN, light = PLAIN, dark = PLAIN }
end

function VM.crew(loadout: Loadout, owns: Owns): { CrewCard }
	local current = CosmeticRules.currentEmployee(loadout, owns)
	local cards: { CrewCard } = {}
	local hire: { [string]: number } = {}
	for _, id in CosmeticRegistry.employees() do
		local item = CosmeticRegistry.get(id)
		local profile = EmployeeProfileRegistry.get(id)
		if item ~= nil then
			hire[id] = item.price or 0
			local look = CosmeticRules.lookFor(loadout, id, owns)
			local skin = CosmeticRegistry.get(look.skin)
			local state: CrewState = if id == current then "wearing" elseif owns(id) then "owned" else "locked"
			table.insert(cards, {
				id = id,
				name = item.name,
				kind = if profile ~= nil then profile.kind else "",
				line = if profile ~= nil then profile.line else "",
				ability = if profile ~= nil then profile.ability.name else "",
				abilityImage = if profile ~= nil then UIAssets.iconImage(profile.ability.icon) else nil,
				state = state,
				price = if state == "locked" then item.price else nil,
				priceText = if state == "locked" and item.price ~= nil
					then ToonStyleViewModel.grouped(item.price)
					else nil,
				skinName = if skin ~= nil then skin.name else "",
				skinKey = VM.skinKey(look.skin),
				color = colorOf(id),
			})
		end
	end
	table.sort(cards, function(a: CrewCard, b: CrewCard): boolean
		if hire[a.id] ~= hire[b.id] then
			return hire[a.id] < hire[b.id]
		end
		return a.id < b.id
	end)
	return cards
end

--[=[
	The idle item the page's hero plays (the key after the dot; nil = the skin's own idle): `selected` on the Idles tab
	when it fits the worn skin, else the worn idle.
]=]
function VM.heroIdle(employee: string, loadout: Loadout, owns: Owns, selected: Item?): string?
	local look = CosmeticRules.lookFor(loadout, employee, owns)
	local id = look.idle
	if selected ~= nil and selected.kind == "idle" and CosmeticRules.idleFits(selected.id, look.skin) then
		id = selected.id
	end
	local item = CosmeticRegistry.get(id)
	return if item ~= nil and item.source ~= "default" then CosmeticRegistry.keyOf(item.id) else nil
end

VM.items = InventoryItemViewModel.items

--[=[
	A page tab's rows: Skins is the employee's skins, then a row of the vacuum skins (one vacuum for the whole crew);
	Emotes and Idles one row each; About none.
]=]
function VM.sections(tab: PageTab, employee: string, loadout: Loadout, owns: Owns): { Section }
	if tab == "skins" then
		return {
			{ title = nil, cards = VM.items("skin", employee, loadout, owns) },
			{ title = "Vacuum skins: one for the whole crew", cards = VM.items("vacuum", employee, loadout, owns) },
		}
	elseif tab == "emotes" then
		return { { title = nil, cards = VM.items("emote", employee, loadout, owns) } }
	elseif tab == "idles" then
		return { { title = nil, cards = VM.items("idle", employee, loadout, owns) } }
	end
	return {}
end

VM.detail = InventoryItemViewModel.detail

--[=[
	The change Wear sends for `item` on `employee`'s page (a skin in colour style `style`, default 1; an idle for that
	employee).
]=]
function VM.change(item: Item, employee: string, slot: number?, style: number?): CosmeticTypes.Change
	if item.kind == "emote" then
		return { kind = "emote", employee = item.employee or employee, slot = slot or 1, id = item.id }
	elseif item.kind == "vacuum" then
		return { kind = "vacuum", id = item.id }
	elseif item.kind == "idle" then
		return { kind = "idle", employee = employee, id = item.id }
	end
	return { kind = "skin", id = item.id, style = style or 1 }
end

function VM.chat(loadout: Loadout, owns: Owns): ChatView
	local slots: { StickerSlot } = {}
	for slot, id in loadout.stickers do
		local item = if id ~= "" then CosmeticRegistry.get(id) else nil
		-- A sticker is owned through its pack.
		local pack = if item ~= nil then item.pack else nil
		local usable = item ~= nil and item.kind == "sticker" and (owns(id) or (pack ~= nil and owns(pack)))
		table.insert(slots, {
			slot = slot,
			id = if usable and item ~= nil then item.id else nil,
			name = if usable and item ~= nil then item.name else "Empty",
			image = if usable then CalloutAssets.stickerImage(id) else nil,
			empty = not usable,
		})
	end
	local packs: { Pack } = {}
	for _, pack in CosmeticRegistry.ofKind("stickerPack") do
		local stickers: { Sticker } = {}
		for _, sticker in CosmeticRegistry.ofKind("sticker") do
			if sticker.pack == pack.id then
				table.insert(
					stickers,
					{ id = sticker.id, name = sticker.name, image = CalloutAssets.stickerImage(sticker.id) }
				)
			end
		end
		local price = pack.price
		table.insert(packs, {
			id = pack.id,
			name = pack.name,
			rarity = pack.rarity,
			owned = owns(pack.id),
			price = if price ~= nil then ToonStyleViewModel.grouped(price) else nil,
			stickers = stickers,
		})
	end
	return { slots = slots, packs = packs }
end

-- The slot a picked sticker goes in: the chosen one, else the first empty one, else slot 1.
function VM.stickerSlotFor(slots: { StickerSlot }, chosen: number?): number
	if chosen ~= nil then
		return chosen
	end
	for _, slot in slots do
		if slot.empty then
			return slot.slot
		end
	end
	return 1
end

function VM.stats(employee: string): { StatRow }
	local profile = EmployeeProfileRegistry.get(employee)
	local rows: { StatRow } = {}
	if profile == nil then
		return rows
	end
	for _, stat: EmployeeProfileRegistry.Stat in EmployeeProfileRegistry.STATS do
		table.insert(
			rows,
			{ label = STAT_LABEL[stat], hint = STAT_HINT[stat], icon = STAT_ICON[stat], value = profile.stats[stat] }
		)
	end
	return rows
end

-- A page tab from a stored string (anything unknown is Skins).
function VM.pageTab(value: string): PageTab
	if value == "idles" then
		return "idles"
	elseif value == "about" then
		return "about"
	elseif value == "emotes" then
		return "emotes"
	end
	return "skins"
end

function VM.tabs(): { Tab }
	return {
		{ id = "crew", text = "Crew", soon = false, icon = "pippaHappy" },
		{ id = "wheel", text = "Chat wheel", soon = false, icon = "stickers" },
	}
end

function VM.layout(virtual: Vector2, phone: boolean): Layout
	local safe = if phone then UIToonConstants.SAFE.phone else UIToonConstants.SAFE.desktop
	-- On a phone the bar starts low enough that a selected tab's lift and ring stay under the safe top (FEATURED's top
	-- was cut by the screen's edge at 6).
	local barY = if phone then safe.top + ToonMenuBarViewModel.SELECTED_REACH - ToonMenuBarViewModel.TAB_TOP else 14
	local barHeight = if phone then 50 else 76
	local gap = if phone then 10 else 22
	local x = safe.left
	local y = barY + barHeight + gap + (if phone then 4 else 12)
	local width = math.max(0, virtual.X - safe.left - safe.right)
	local height = math.max(0, virtual.Y - y - safe.bottom)
	-- The concept's proportions: Crew cards fill the height; the page is grid | hero | detail.
	-- The flags above the cards; below: the wearing ring's 8 px overhang, 8 px of air and the 6 px scroll bar.
	local crewPad = { top = 16, bottom = 22 }
	local cardHeight = math.min(height - crewPad.top - crewPad.bottom, if phone then 290 else 760)
	local gridWidth = math.floor(width * (if phone then 0.34 else 0.29))
	local heroWidth = math.floor(width * (if phone then 0.3 else 0.36))
	local cellWidth = math.floor((gridWidth - 2 * UIToonConstants.DEPTH.outline - 24 - gap) / 2)
	return {
		phone = phone,
		barY = barY,
		barHeight = barHeight,
		titleX = if phone then 104 else 150,
		titleSize = if phone then 34 else 64,
		content = { x = x, y = y, width = width, height = height },
		crewCard = Vector2.new(math.floor(cardHeight * (if phone then 0.78 else 0.54)), cardHeight),
		crewPad = crewPad,
		gap = gap,
		gridWidth = gridWidth,
		heroWidth = heroWidth,
		detailWidth = width - gridWidth - heroWidth - 2 * gap,
		cell = Vector2.new(cellWidth, math.floor(cellWidth * 0.9)),
		textSize = if phone then 14 else 24,
		headingSize = if phone then 30 else 64,
	}
end

function VM.color(employee: string): { body: Color3, light: Color3, dark: Color3 }
	return colorOf(employee)
end

return VM
