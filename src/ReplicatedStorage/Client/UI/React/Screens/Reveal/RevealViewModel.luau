--!strict
--[=[
	RevealViewModel: what the reveal screen shows for a grant (CosmeticRevealStore.Reveal): one screen, louder up the
	rarity ladder (Uncommon a quick pop; Rare adds rays; Epic stripes and sparkles; Legendary confetti; Odd red goo),
	the title ("LEGENDARY!"), the ribbon ("New skin for Pippa"), the item to show in 3D, and the buttons. The main
	button's words fit what you got (owner 11-14): Wear it! for a skin, Use it! for an idle or a vacuum; once it is on
	it says so (Wearing it!, Using it!). A spot item is never on or off (owner 11-14): Add to wheel! (an emote) and Use
	stickers! (a sticker pack) open a small picker on the reveal to choose the spot (owner 11-14: never a whole new
	menu): the emote's wheel (`wheel`; taking a filled slot asks first, `swapQuestion`) or the pack's stickers and your
	sticker spots (`stickers`). The picker's slots are the Inventory's own (InventoryViewModel.detail and .chat). An idle plays on the skin the player wears (Classic by
	default, never forced onto its Legendary skin; every idle fits every skin of its employee). A new skin with colour styles shows a chip per style first, to pick which one to wear. Nice!
	otherwise. A buy with more than one item (a bundle, a deal) shows every item as a tile: tap one to put it in front
	with its own button; the screen stays open after you use something and leaves only on Done (a single item closes
	on its button, Later leaves it). An employee is a hire: "YOU'RE HIRED!", their ID card and ability, Start! after
	the first-join pick, Equip! + Later after a purchase. A Robux buy that is not a cosmetic (owner 11-15: Fortnite and
	Marvel Rivals both thank you) is "+600 GLEAM!" with the bundle's art, a pass's card (YOU GOT IT!), or COFFEE TIME!
	with the cup: a gold screen, Thank you!, and one Nice! that closes it.

	@class RevealViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopTypes = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopTypes)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local InventoryViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Inventory.InventoryViewModel)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)

export type Reveal = {
	ids: { string },
	source: string,
	duplicate: boolean?,
	refund: number?,
	currency: ("gloom" | "gleam")?,
	purchase: ShopTypes.Purchase?,
}

-- A purchase's picture: a kit icon or an image id (a Gleam bundle's product icon).
export type Art = { icon: UIAssets.ToonIcon?, image: string? }

-- `foil`: a bright sweep across the screen as it opens (Legendary, Odd and hires).
export type Effects = {
	rays: boolean,
	stripes: boolean,
	sparkles: boolean,
	confetti: boolean,
	goo: boolean,
	foil: boolean,
}

-- Which small picker the main button opens on the reveal: an emote's wheel, or a sticker pack's spots.
export type Picker = "wheel" | "stickers"

-- One colour style's chip: a short name and its colours (the fur, then the outfit).
export type StyleChip = { name: string, swatch: { Color3 } }

-- One item of a buy with more than one: a tile to tap. `selected`: the one in front; `done`: it is already on.
export type Tile = { id: string, name: string, kind: string, selected: boolean, done: boolean, skinKey: string? }

-- What the player wears now, to word the button and pick slots (nil: a new player's loadout, owning everything), and
-- which of the reveal's items is in front (default the first).
export type Context = {
	loadout: CosmeticTypes.Loadout,
	owns: (id: string) -> boolean,
	focus: number?,
}

export type View = {
	kind: "hire" | "item" | "purchase",
	title: string,
	rarity: CosmeticTypes.Rarity,
	ribbon: string,
	name: string,
	employee: string,
	skinKey: string?,
	-- A vacuum (Cosmetic id): shown on the player's own employee (CosmeticOutfitRules.tryOn), from behind.
	vacuum: string?,
	-- An idle plays as itself (its key, on the skin the player wears), an emote loops (its id), and a sticker pack
	-- shows its stickers instead of an employee.
	idle: string?,
	emote: string?,
	stickers: boolean,
	-- A buy with more than one item: every item, a tile each (empty for a single item).
	items: { Tile },
	multi: boolean,
	effects: Effects,
	primary: string,
	-- What the primary button equips (empty: nothing to put on); a skin's colour style comes from VM.wear.
	changes: { CosmeticTypes.Change },
	-- The item in front is already on: the button shows it, greyed.
	done: boolean,
	-- The screen stays open after the primary button (a buy with more than one item, or a picker that comes back
	-- here); it leaves on `leave`.
	stays: boolean,
	-- An emote or a sticker pack: the small picker the main button opens over the reveal to choose its spot.
	picker: Picker?,
	-- A new skin's colour styles, a chip each (name and colours): pick which one Wear it! puts on. Empty otherwise.
	styles: { StyleChip },
	-- The second button and its words: "Later" (a single item), "Done" (a buy with more than one).
	later: boolean,
	leave: string,
	-- A hire's ID card line and ability.
	job: string,
	ability: { name: string, line: string, image: string? }?,
	-- A purchase: its picture, and what it does (under the name).
	art: Art?,
	line: string?,
}

local TITLE: { [CosmeticTypes.Rarity]: string } = {
	default = "NEW!",
	uncommon = "NICE!",
	rare = "RARE!",
	epic = "EPIC!",
	legendary = "LEGENDARY!",
	odd = "ODD!",
}

local RANK: { [CosmeticTypes.Rarity]: number } =
	{ default = 0, uncommon = 1, rare = 2, epic = 3, legendary = 4, odd = 5 }

local KIND_WORD: { [CosmeticTypes.Kind]: string } = {
	employee = "Employee",
	skin = "Skin",
	idle = "Idle",
	emote = "Emote",
	stickerPack = "Sticker pack",
	sticker = "Sticker",
	vacuum = "Vacuum",
}

-- The main button's words by kind, and once it is on.
local USE_WORD: { [CosmeticTypes.Kind]: string? } = {
	skin = "Wear it!",
	idle = "Use it!",
	emote = "Add to wheel!",
	stickerPack = "Use stickers!",
	vacuum = "Use it!",
}
local DONE_WORD: { [CosmeticTypes.Kind]: string? } = {
	skin = "Wearing it!",
	idle = "Using it!",
	vacuum = "Using it!",
}

local VM = { SCENE = "reveal" }

-- A pass's picture on the purchase screen, by MarketplaceRegistry key (a pass not listed shows the Shop icon).
local PASS_ICON: { [string]: UIAssets.ToonIcon } = { bigCrew = "truck" }

-- The "You bought it!" screen for a Robux buy of Gleam, a pass or coffee.
local function purchaseView(purchase: ShopTypes.Purchase): View
	local title, name, line = "YOU GOT IT!", purchase.key, nil
	local art: Art = { icon = "shop" }
	if purchase.kind == "gleam" then
		local amount = ToonStyleViewModel.grouped(purchase.amount)
		title, name, line = `+{amount} GLEAM!`, `{amount} Gleam`, "Spend it in the Shop!"
		art = { icon = "gleamPile" }
		for _, bundle in ShopConstants.BUNDLES do
			if bundle.key == purchase.key then
				art = { image = bundle.image }
			end
		end
	elseif purchase.kind == "coffee" then
		title, name = "COFFEE TIME!", "Coffee for the crew"
		line = `2x Credits and Gloom for your crew for {purchase.amount} minutes of shifts!`
		art = { icon = "coffee" }
	else
		local copy = ShopConstants.PASS_COPY[purchase.key]
		if copy ~= nil then
			name, line = copy.name, copy.line
		end
		art = { icon = PASS_ICON[purchase.key] or "shop" }
	end
	return {
		kind = "purchase",
		title = title,
		rarity = "legendary",
		ribbon = "Thank you!",
		name = name,
		employee = CosmeticConstants.DEFAULT_EMPLOYEE,
		stickers = false,
		items = {},
		multi = false,
		effects = { rays = true, stripes = false, sparkles = false, confetti = true, goo = false, foil = true },
		primary = "Nice!",
		changes = {},
		done = false,
		stays = false,
		later = false,
		leave = "Later",
		styles = {},
		job = "",
		art = art,
		line = line,
	}
end

-- What putting `item` on would send, and how the button reads: the changes still allowed, whether it is already on,
-- and the words.
-- A slot item opens its picker instead (owner 11-14: stickers and the emote wheel are not on or off; you choose the
-- spot): an emote its employee's wheel, a sticker pack the Inventory's sticker spots.
local function useOf(item: CosmeticTypes.Item, context: Context): ({ CosmeticTypes.Change }, boolean, string, Picker?)
	local loadout, owns = context.loadout, context.owns
	local employee = item.employee or CosmeticConstants.DEFAULT_EMPLOYEE
	local use = USE_WORD[item.kind]
	if use == nil then
		return {}, false, "Nice!", nil
	end
	if item.kind == "stickerPack" then
		return {}, false, use, "stickers"
	elseif item.kind == "emote" then
		return {}, false, use, "wheel"
	end
	local change: CosmeticTypes.Change
	if item.kind == "skin" then
		change = { kind = "skin", id = item.id, style = 1 }
	elseif item.kind == "idle" then
		change = { kind = "idle", employee = employee, id = item.id }
	else
		change = { kind = "vacuum", id = item.id }
	end
	if item.kind == "skin" then
		-- A skin is on when it is the worn skin (any colour style; the chips pick another).
		if CosmeticRules.lookFor(loadout, employee, owns).skin == item.id then
			return {}, true, DONE_WORD[item.kind] or "", nil
		end
		return { change }, false, use, nil
	end
	local ok, reason = CosmeticRules.checkEquip(loadout, change, owns)
	if ok then
		return { change }, false, use, nil
	elseif reason == "no change" then
		return {}, true, DONE_WORD[item.kind] or "", nil
	end
	return {}, false, "Nice!", nil
end

-- The key of the skin the player wears on `employee`; nil for the employee's free skin (Classic).
local function wornSkinKey(context: Context, employee: string): string?
	local skin = CosmeticRules.lookFor(context.loadout, employee, context.owns).skin
	local item = CosmeticRegistry.get(skin)
	if item == nil or item.source == "default" then
		return nil
	end
	return CosmeticRegistry.keyOf(skin)
end

local function everything(): boolean
	return true
end

local function effectsOf(rarity: CosmeticTypes.Rarity): Effects
	local rank = RANK[rarity]
	return {
		rays = rank >= 2,
		stripes = rank >= 3,
		sparkles = rank >= 3,
		confetti = rarity == "legendary",
		goo = rarity == "odd",
		foil = rank >= 4,
	}
end

function VM.view(reveal: Reveal, given: Context?): View
	local context: Context = given or { loadout = CosmeticConstants.defaultLoadout(), owns = everything }
	local purchase = reveal.purchase
	if purchase ~= nil and #reveal.ids == 0 then
		return purchaseView(purchase)
	end
	local focus = context.focus or 1
	if reveal.ids[focus] == nil then
		focus = 1
	end
	local item = CosmeticRegistry.get(reveal.ids[focus] or "")
	if item == nil then
		return {
			kind = "item",
			title = "NEW!",
			rarity = "default",
			ribbon = "Something new",
			name = reveal.ids[1] or "",
			employee = "Pippa",
			stickers = false,
			items = {},
			multi = false,
			effects = effectsOf("default"),
			primary = "Nice!",
			changes = {},
			done = false,
			stays = false,
			later = false,
			leave = "Later",
			styles = {},
			job = "",
		}
	end
	if item.kind == "employee" then
		local profile = EmployeeProfileRegistry.get(item.id)
		local fromPick = reveal.source == "pick"
		return {
			kind = "hire",
			title = "YOU'RE HIRED!",
			rarity = item.rarity,
			ribbon = "Welcome to the night crew",
			name = item.name,
			employee = item.id,
			stickers = false,
			items = {},
			multi = false,
			effects = { rays = true, stripes = false, sparkles = true, confetti = true, goo = false, foil = true },
			primary = if fromPick then "Start!" else "Equip!",
			changes = if fromPick then {} else { { kind = "employee", id = item.id } },
			done = false,
			stays = false,
			later = not fromPick,
			leave = "Later",
			styles = {},
			job = "Night cleaner",
			ability = if profile ~= nil
				then {
					name = profile.ability.name,
					line = profile.ability.line,
					image = UIAssets.iconImage(profile.ability.icon),
				}
				else nil,
		}
	end
	-- A buy with more than one item (a bundle announces every item it granted, the hero first): a tile each.
	local items: { Tile } = {}
	if #reveal.ids > 1 then
		for index, id in reveal.ids do
			local each = CosmeticRegistry.get(id)
			if each ~= nil then
				local _, eachDone = useOf(each, context)
				table.insert(items, {
					id = each.id,
					name = each.name,
					kind = KIND_WORD[each.kind],
					selected = index == focus,
					done = eachDone and reveal.duplicate ~= true,
					skinKey = if each.kind == "skin" then CosmeticRegistry.keyOf(each.id) else nil,
				})
			end
		end
	end
	local multi = #items > 1
	local word = string.lower(KIND_WORD[item.kind])
	local duplicate = reveal.duplicate == true
	local currencyWord = if reveal.currency == "gleam" then "Gleam" else "Gloom"
	local ribbon = if duplicate
		then `You already have this! +{ToonStyleViewModel.grouped(reveal.refund or 0)} {currencyWord} back`
		elseif item.kind == "stickerPack" then "New sticker pack"
		elseif item.kind == "vacuum" then "New vacuum for your crew"
		elseif item.employee ~= nil then `New {word} for {item.employee}`
		else `New {word} for everyone`
	local employee = item.employee or "Pippa"
	local changes: { CosmeticTypes.Change } = {}
	local done = false
	local primary = "Nice!"
	local picker: Picker? = nil
	if not duplicate then
		changes, done, primary, picker = useOf(item, context)
	end
	local usable = #changes > 0
	-- Open while a picker is up (it comes back here), and for a buy with more than one item.
	local stays = multi or picker ~= nil
	local styles: { StyleChip } = {}
	if item.kind == "skin" and not duplicate then
		for _, style in EmployeeSkinRules.stylesFor(item.employee, CosmeticRegistry.keyOf(item.id)) do
			table.insert(styles, { name = style.name, swatch = style.swatch })
		end
	end
	return {
		kind = "item",
		title = TITLE[item.rarity],
		rarity = item.rarity,
		ribbon = ribbon,
		name = item.name,
		employee = employee,
		skinKey = if item.kind == "skin"
			then CosmeticRegistry.keyOf(item.id)
			elseif item.kind == "idle" then wornSkinKey(context, employee)
			else nil,
		vacuum = if item.kind == "vacuum" then item.id else nil,
		idle = if item.kind == "idle" then CosmeticRegistry.keyOf(item.id) else nil,
		emote = if item.kind == "emote" then item.id else nil,
		stickers = item.kind == "stickerPack",
		items = items,
		multi = multi,
		effects = effectsOf(item.rarity),
		primary = primary,
		changes = changes,
		done = done,
		stays = stays,
		picker = picker,
		-- Something already on greys the main button, so Later is the way out.
		later = stays or usable or done,
		leave = if stays then "Done" else "Later",
		styles = styles,
		job = "",
	}
end

--[=[
	What the main button sends: the view's changes, a skin in colour style `style` when it has that style (else its
	first). Empty when there is nothing to put on.
]=]
function VM.wear(view: View, style: number): { CosmeticTypes.Change }
	local result: { CosmeticTypes.Change } = {}
	for _, change in view.changes do
		if change.kind == "skin" then
			table.insert(
				result,
				{ kind = "skin", id = change.id, style = if view.styles[style] ~= nil then style else 1 }
			)
		else
			table.insert(result, change)
		end
	end
	return result
end

--[=[
	The small emote picker's wheel for `emoteId` on its employee: the Inventory's own wheel slots (what is in each,
	`mine` = this emote's slot).
]=]
function VM.wheel(emoteId: string, context: Context): { InventoryViewModel.WheelSlot }
	local item = CosmeticRegistry.get(emoteId)
	if item == nil then
		return {}
	end
	return InventoryViewModel.detail(item, context.loadout, context.owns).wheel or {}
end

--[=[
	The question before putting `name` in a slot that holds another emote; nil for an empty slot or its own.
]=]
function VM.swapQuestion(slot: InventoryViewModel.WheelSlot, name: string): string?
	if slot.empty or slot.mine then
		return nil
	end
	return `Swap {slot.name} for {name}?`
end

function VM.wheelChange(emoteId: string, slot: number): CosmeticTypes.Change
	local item = CosmeticRegistry.get(emoteId)
	local employee = if item ~= nil and item.employee ~= nil then item.employee else CosmeticConstants.DEFAULT_EMPLOYEE
	return { kind = "emote", employee = employee, slot = slot, id = emoteId }
end

export type StickerPick = { slots: { InventoryViewModel.StickerSlot }, stickers: { InventoryViewModel.Sticker } }

--[=[
	The small sticker picker for pack `packId`: your sticker spots and the pack's own stickers (the Inventory's chat view).
]=]
function VM.stickers(packId: string, context: Context): StickerPick
	local chat = InventoryViewModel.chat(context.loadout, context.owns)
	local stickers: { InventoryViewModel.Sticker } = {}
	for _, pack in chat.packs do
		if pack.id == packId then
			stickers = pack.stickers
		end
	end
	return { slots = chat.slots, stickers = stickers }
end

function VM.stickerChange(stickerId: string, slot: number): CosmeticTypes.Change
	return { kind = "sticker", slot = slot, id = stickerId }
end

return VM
