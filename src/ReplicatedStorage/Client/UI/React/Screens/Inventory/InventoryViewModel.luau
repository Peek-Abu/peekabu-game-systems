--!strict
--[=[
	InventoryViewModel: everything the Inventory screens show, worked out from the catalogue (CosmeticRegistry), the
	employee profiles (EmployeeProfileRegistry), the player's loadout and what they own. Nothing here is per
	character: a new employee or skin in the registries shows up on every screen by itself.

	- `crew`: one card per employee (free ones first): the skin they wear, and whether they are worn, owned or locked.
	- `items`: an employee's skins or idles as grid cards (the free one first, then by rarity) with their footer band.
	- `band` / `action`: where a locked item comes from (the card's footer) and the detail panel's main button.
	- `detail`: the right-hand panel for the selected item (flags, lore, Styles row, Comes with, button).
	- `change`: the CosmeticServiceClient change Wear sends.
	- `stats`: the About tab's five stat rows.

	@class InventoryViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetic = ReplicatedStorage.Shared.Features.Cosmetic
local CosmeticRegistry = require(Cosmetic.Data.CosmeticRegistry)
local CosmeticRules = require(Cosmetic.Rules.CosmeticRules)
local CosmeticTypes = require(Cosmetic.Data.CosmeticTypes)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonSourceBand = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonSourceBand)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

type Item = CosmeticTypes.Item
type Loadout = CosmeticTypes.Loadout
type Owns = (id: string) -> boolean

export type Band = { kind: ToonSourceBand.Kind, text: string }
-- `kind`: what pressing it does: wear the item, open its Shop page, or nothing (it says where to get the item).
-- `price`: shown on a Shop button.
export type Action = {
	text: string,
	enabled: boolean,
	variant: ToonStyleViewModel.Variant,
	kind: "wear" | "shop" | "none",
	price: { currency: "gleam" | "credits", amount: string }?,
}
export type Bundled = { id: string, name: string, kind: CosmeticTypes.Kind, employee: string? }
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

export type ItemCard = {
	id: string,
	name: string,
	rarity: CosmeticTypes.Rarity,
	owned: boolean,
	worn: boolean,
	-- Locked art is darkened.
	dim: boolean,
	new: boolean,
	band: Band?,
}

export type Detail = {
	id: string,
	name: string,
	rarity: CosmeticTypes.Rarity,
	rarityText: string,
	new: boolean,
	-- "Pippa skin", "Idle for everyone".
	line: string,
	lore: string,
	styles: { visible: boolean, count: number, enabled: boolean, note: string },
	comesWith: { Bundled },
	action: Action,
}

export type StatRow = { stat: EmployeeProfileRegistry.Stat, label: string, icon: UIAssets.ToonIcon, value: number }
export type Tab = { id: string, text: string, soon: boolean, icon: UIAssets.ToonIcon? }
export type PageTab = "skins" | "idles" | "about"

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
	gap: number,
	-- The character page (its tabs are in the menu bar): grid | hero | detail.
	gridWidth: number,
	heroWidth: number,
	detailWidth: number,
	cell: Vector2,
	textSize: number,
	headingSize: number,
}

local RARITY_RANK: { [CosmeticTypes.Rarity]: number } = {
	default = 0,
	uncommon = 1,
	rare = 2,
	epic = 3,
	legendary = 4,
	odd = 5,
}

local STAT_LABEL: { [EmployeeProfileRegistry.Stat]: string } = {
	speed = "Speed",
	stamina = "Stamina",
	strength = "Strength",
	suction = "Suction",
	quiet = "Quiet",
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

local PAGE_TABS: { PageTab } = { "skins", "idles", "about" }
VM.PAGE_TABS = table.freeze(PAGE_TABS)

-- The EmployeeRegistry art key of a skin id ("Pippa.OwnerSpecial" -> "OwnerSpecial").
function VM.skinKey(id: string): string
	return string.match(id, "^[^%.]+%.(.+)$") or id
end

-- The footer band: nil for an owned item, "Wearing" on the worn one, else where it comes from.
function VM.band(item: Item, owned: boolean, worn: boolean): Band?
	if worn then
		return { kind = "wearing", text = "Wearing" }
	end
	if owned then
		return nil
	end
	local source = item.source
	if source == "credits" or source == "gleam" then
		return { kind = source, text = if item.price ~= nil then ToonStyleViewModel.grouped(item.price) else "Shop" }
	elseif source == "gloomLocker" then
		return { kind = "locker", text = "Gloom Locker" }
	elseif source == "gleamLocker" then
		return { kind = "locker", text = "Gleam Locker" }
	elseif source == "goal" then
		return { kind = "goal", text = "Goal" }
	elseif source == "event" or source == "gift" then
		return { kind = "missed", text = "Missed it" }
	elseif source == "later" then
		return { kind = "later", text = "Coming later" }
	end
	-- A free item is always owned; kept for completeness.
	return nil
end

-- The detail panel's main button. Only Wear does anything; the rest say where to get the item.
function VM.action(item: Item, owned: boolean, worn: boolean): Action
	if worn then
		return { text = "Wearing", enabled = false, variant = "secondary", kind = "none" }
	end
	if owned then
		return { text = "Wear", enabled = true, variant = "primary", kind = "wear" }
	end
	local source = item.source
	if (source == "credits" or source == "gleam") and item.price ~= nil then
		return {
			text = "See in Shop",
			enabled = true,
			variant = "gleam",
			kind = "shop",
			price = { currency = source, amount = ToonStyleViewModel.grouped(item.price) },
		}
	elseif source == "gloomLocker" then
		return { text = "Gloom Locker", enabled = false, variant = "night", kind = "none" }
	elseif source == "gleamLocker" then
		return { text = "Gleam Locker", enabled = false, variant = "gleam", kind = "none" }
	elseif source == "goal" then
		return { text = "Earn it playing", enabled = false, variant = "primary", kind = "none" }
	elseif source == "event" or source == "gift" then
		return { text = "Missed it", enabled = false, variant = "secondary", kind = "none" }
	end
	return { text = "Coming later", enabled = false, variant = "lilac", kind = "none" }
end

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

local function wornId(kind: "skin" | "idle", employee: string, loadout: Loadout, owns: Owns): string
	local look = CosmeticRules.lookFor(loadout, employee, owns)
	return if kind == "skin" then look.skin else look.idle
end

local function isNew(item: Item, owned: boolean, loadout: Loadout): boolean
	return owned and item.source ~= "default" and loadout.seen[item.id] ~= true
end

-- The employee's skins or idles (idles include the shared ones), the free one first, then by rarity.
function VM.items(kind: "skin" | "idle", employee: string, loadout: Loadout, owns: Owns): { ItemCard }
	local worn = wornId(kind, employee, loadout, owns)
	local list = table.clone(CosmeticRegistry.ofKind(kind, employee))
	table.sort(list, function(a: Item, b: Item): boolean
		local fa = a.source == "default" and a.employee == employee
		local fb = b.source == "default" and b.employee == employee
		if fa ~= fb then
			return fa
		end
		if RARITY_RANK[a.rarity] ~= RARITY_RANK[b.rarity] then
			return RARITY_RANK[a.rarity] < RARITY_RANK[b.rarity]
		end
		return a.id < b.id
	end)
	local cards: { ItemCard } = {}
	for _, item in list do
		local owned = owns(item.id)
		local isWorn = item.id == worn
		table.insert(cards, {
			id = item.id,
			name = item.name,
			rarity = item.rarity,
			owned = owned,
			worn = isWorn,
			dim = not owned,
			new = isNew(item, owned, loadout),
			band = VM.band(item, owned, isWorn),
		})
	end
	return cards
end

function VM.detail(item: Item, loadout: Loadout, owns: Owns): Detail
	local owned = owns(item.id)
	local employee = item.employee
	local worn = false
	if employee ~= nil and (item.kind == "skin" or item.kind == "idle") then
		worn = wornId(item.kind, employee, loadout, owns) == item.id
	end
	local comesWith: { Bundled } = {}
	local bundle = item.bundle
	if bundle ~= nil then
		for _, id in bundle do
			local other = CosmeticRegistry.get(id)
			if other ~= nil then
				table.insert(
					comesWith,
					{ id = other.id, name = other.name, kind = other.kind, employee = other.employee }
				)
			end
		end
	end
	local kindWord = if item.kind == "idle" then "idle" elseif item.kind == "emote" then "emote" else "skin"
	local styles = item.styles or 1
	return {
		id = item.id,
		name = item.name,
		rarity = item.rarity,
		rarityText = if item.rarity == "default" then "CLASSIC" else string.upper(item.rarity),
		new = isNew(item, owned, loadout),
		line = if employee ~= nil then `{employee} {kindWord}` else `{kindWord} for everyone`,
		lore = item.lore,
		styles = { visible = styles > 1, count = styles, enabled = false, note = "Coming soon" },
		comesWith = comesWith,
		action = VM.action(item, owned, worn),
	}
end

--[=[
	The change Wear sends for `item` on `employee`'s page (a skin in its first style; an idle for that employee).
]=]
function VM.change(item: Item, employee: string): CosmeticTypes.Change
	if item.kind == "idle" then
		return { kind = "idle", employee = employee, id = item.id }
	end
	return { kind = "skin", id = item.id, style = 1 }
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
			{ stat = stat, label = STAT_LABEL[stat], icon = STAT_ICON[stat], value = profile.stats[stat] }
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
	end
	return "skins"
end

function VM.tabs(): { Tab }
	return {
		{ id = "crew", text = "Crew", soon = false, icon = "pippaHappy" },
		{ id = "vacuums", text = "Vacuums", soon = false, icon = "vacuum" },
		{ id = "wheel", text = "Chat wheel", soon = true },
	}
end

function VM.layout(virtual: Vector2, phone: boolean): Layout
	local safe = if phone then UIToonConstants.SAFE.phone else UIToonConstants.SAFE.desktop
	local barY = if phone then 6 else 14
	local barHeight = if phone then 50 else 76
	local gap = if phone then 10 else 22
	local x = safe.left
	local y = barY + barHeight + gap + (if phone then 4 else 12)
	local width = math.max(0, virtual.X - safe.left - safe.right)
	local height = math.max(0, virtual.Y - y - safe.bottom)
	-- The concept's proportions: Crew cards fill the height; the page is grid | hero | detail.
	local cardHeight = math.min(height - 16, if phone then 290 else 760)
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
