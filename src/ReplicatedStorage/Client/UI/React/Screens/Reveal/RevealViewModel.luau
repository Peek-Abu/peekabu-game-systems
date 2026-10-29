--!strict
--[=[
	RevealViewModel: what the reveal screen shows for a grant (CosmeticRevealStore.Reveal): one screen, louder up the
	rarity ladder (Uncommon a quick pop; Rare adds rays; Epic stripes and sparkles; Legendary confetti; Odd red goo),
	the title ("LEGENDARY!"), the ribbon ("New skin for Pippa"), the item to show in 3D, what came with it, and the
	buttons: Wear it! + Later for something you can wear (a new skin with colour styles shows a chip per style first,
	to pick which one to wear), Nice! otherwise. An employee is a hire: "YOU'RE HIRED!",
	their ID card and ability, Start! after the first-join pick, Equip! + Later after a purchase.

	@class RevealViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)
local EmployeeSkinRules = require(ReplicatedStorage.Shared.Features.Employee.Rules.EmployeeSkinRules)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)

export type Reveal = {
	ids: { string },
	source: string,
	duplicate: boolean?,
	refund: number?,
	currency: ("gloom" | "gleam")?,
}

-- `foil`: a bright sweep across the screen as it opens (Legendary, Odd and hires).
export type Effects = {
	rays: boolean,
	stripes: boolean,
	sparkles: boolean,
	confetti: boolean,
	goo: boolean,
	foil: boolean,
}

-- One colour style's chip: a short name and its colours (the fur, then the outfit).
export type StyleChip = { name: string, swatch: { Color3 } }

export type View = {
	kind: "hire" | "item",
	title: string,
	rarity: CosmeticTypes.Rarity,
	ribbon: string,
	name: string,
	employee: string,
	skinKey: string?,
	-- A vacuum (Cosmetic id): shown on the player's own employee (CosmeticOutfitRules.tryOn), from behind.
	vacuum: string?,
	alsoGot: { { id: string, name: string, kind: string } },
	effects: Effects,
	primary: string,
	-- What the primary button equips (nil: it only closes); a skin's colour style comes from VM.wear.
	change: CosmeticTypes.Change?,
	-- A new skin's colour styles, a chip each (name and colours): pick which one Wear it! puts on. Empty otherwise.
	styles: { StyleChip },
	later: boolean,
	-- A hire's ID card line and ability.
	job: string,
	ability: { name: string, line: string, image: string? }?,
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

local VM = { SCENE = "reveal" }

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

function VM.view(reveal: Reveal): View
	local item = CosmeticRegistry.get(reveal.ids[1] or "")
	if item == nil then
		return {
			kind = "item",
			title = "NEW!",
			rarity = "default",
			ribbon = "Something new",
			name = reveal.ids[1] or "",
			employee = "Pippa",
			alsoGot = {},
			effects = effectsOf("default"),
			primary = "Nice!",
			later = false,
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
			alsoGot = {},
			effects = { rays = true, stripes = false, sparkles = true, confetti = true, goo = false, foil = true },
			primary = if fromPick then "Start!" else "Equip!",
			change = if fromPick then nil else { kind = "employee", id = item.id },
			later = not fromPick,
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
	local alsoGot: { { id: string, name: string, kind: string } } = {}
	local bundle = item.bundle
	if bundle ~= nil then
		for _, id in bundle do
			local extra = CosmeticRegistry.get(id)
			if extra ~= nil then
				table.insert(alsoGot, { id = extra.id, name = extra.name, kind = KIND_WORD[extra.kind] })
			end
		end
	end
	local word = string.lower(KIND_WORD[item.kind])
	local duplicate = reveal.duplicate == true
	local currencyWord = if reveal.currency == "gleam" then "Gleam" else "Gloom"
	local ribbon = if duplicate
		then `You already have this! +{ToonStyleViewModel.grouped(reveal.refund or 0)} {currencyWord} back`
		elseif item.kind == "stickerPack" then "New sticker pack"
		elseif item.kind == "vacuum" then "New vacuum for your crew"
		elseif item.employee ~= nil then `New {word} for {item.employee}`
		else `New {word} for everyone`
	local change: CosmeticTypes.Change? = nil
	local employee = item.employee or "Pippa"
	if not duplicate then
		if item.kind == "skin" then
			change = { kind = "skin", id = item.id, style = 1 }
		elseif item.kind == "idle" then
			change = { kind = "idle", employee = employee, id = item.id }
		elseif item.kind == "vacuum" then
			change = { kind = "vacuum", id = item.id }
		end
	end
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
		skinKey = if item.kind == "skin" then string.match(item.id, "^[^%.]+%.(.+)$") else nil,
		vacuum = if item.kind == "vacuum" then item.id else nil,
		alsoGot = alsoGot,
		effects = effectsOf(item.rarity),
		primary = if change ~= nil then "Wear it!" else "Nice!",
		change = change,
		later = change ~= nil,
		styles = styles,
		job = "",
	}
end

--[=[
	What Wear it! sends: the view's change, a skin in colour style `style` when it has that style (else its first).
	nil when there is nothing to wear.
]=]
function VM.wear(view: View, style: number): CosmeticTypes.Change?
	local change = view.change
	if change ~= nil and change.kind == "skin" then
		return { kind = "skin", id = change.id, style = if view.styles[style] ~= nil then style else 1 }
	end
	return change
end

return VM
