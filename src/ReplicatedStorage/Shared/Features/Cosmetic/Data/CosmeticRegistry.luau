--!strict
--[=[
	CosmeticRegistry: the catalogue of everything a player can own and wear in Odd Hours (employees, skins, idles,
	emotes, sticker packs and their stickers), looked up by id. Requirements: characters/launch/new-employee-requirements.md;
	design: docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md.

	Ids: `<Employee>.<Name>` for an item that belongs to one employee, a plain name for a shared one, a sticker
	`<Pack>.<Name>`. At load every item but a sticker is registered in EntitlementRegistry under its kind as the
	category, so ownership is the existing `entitlements` slice; a sticker is owned through its pack. Prices and lore
	are first drafts (owner: prices may change).

	Art and animation ids are NOT here yet: the rig facts stay in EmployeeRegistry (step 2 wires skins to palettes).

	@class CosmeticRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local EntitlementRegistry = require(ReplicatedStorage.Shared.Features.Entitlement.Data.EntitlementRegistry)

type Item = CosmeticTypes.Item
type Kind = CosmeticTypes.Kind

local ITEMS: { Item } = {
	-- Employees
	{
		id = "Pippa",
		kind = "employee",
		name = "Pippa",
		rarity = "default",
		source = "default",
		lore = "Quick on her feet and always cheering on her crew.",
	},
	{
		id = "Cappy",
		kind = "employee",
		name = "Cappy",
		rarity = "default",
		source = "credits",
		price = 2500,
		lore = "The boss's nephew. He says the building is NOT haunted.",
	},
	{
		id = "Prickles",
		kind = "employee",
		name = "Prickles",
		rarity = "default",
		source = "credits",
		price = 2500,
		lore = "Looks grumpy, but he is a big softy. He can hide anywhere.",
	},

	-- Free defaults (one skin, idle and emote per employee)
	{
		id = "Pippa.Default",
		kind = "skin",
		employee = "Pippa",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "My favourite bow and my lucky bell!",
	},
	{
		id = "Cappy.Default",
		kind = "skin",
		employee = "Cappy",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "Comfy hoodie. Cap on backwards. Ready.",
	},
	{
		id = "Prickles.Default",
		kind = "skin",
		employee = "Prickles",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "Hard hat on. Flower on. Let's go.",
	},
	{
		id = "Pippa.Classic",
		kind = "idle",
		employee = "Pippa",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "Bouncing, always bouncing.",
	},
	{
		id = "Cappy.Classic",
		kind = "idle",
		employee = "Cappy",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "Hands in the pocket. Totally chill.",
	},
	{
		id = "Prickles.Classic",
		kind = "idle",
		employee = "Prickles",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "Arms crossed. Not impressed.",
	},
	{
		id = "Pippa.Wave",
		kind = "emote",
		employee = "Pippa",
		name = "Big Wave",
		rarity = "default",
		source = "default",
		lore = "Hi, crew! Over here!",
	},
	{
		id = "Cappy.FistBump",
		kind = "emote",
		employee = "Cappy",
		name = "Fist Bump",
		rarity = "default",
		source = "default",
		lore = "Nice work. Don't make it weird.",
	},
	{
		id = "Prickles.Huff",
		kind = "emote",
		employee = "Prickles",
		name = "Huff",
		rarity = "default",
		source = "default",
		lore = "Hmph.",
	},

	-- Pippa
	{
		id = "Pippa.OwnerSpecial",
		kind = "skin",
		employee = "Pippa",
		name = "Lavender Specs",
		rarity = "rare",
		source = "gift",
		lore = "A gift from the boss. Very fancy glasses.",
	},
	{
		id = "Pippa.BubbleBuddy",
		kind = "skin",
		employee = "Pippa",
		name = "Bubble Buddy",
		rarity = "legendary",
		source = "gleam",
		price = 1500,
		styles = 3,
		bundle = { "Pippa.Bubbles", "BubblePack" },
		lore = "Rain or shine, bubbles make cleaning fun!",
	},
	{
		id = "Pippa.GloomTouched",
		kind = "skin",
		employee = "Pippa",
		name = "Gloom-Touched",
		rarity = "uncommon",
		source = "gloomLocker",
		lore = "I stepped in the purple stuff. Oops.",
	},
	{
		id = "Pippa.Gloomkeeper",
		kind = "skin",
		employee = "Pippa",
		name = "Gloomkeeper",
		rarity = "epic",
		source = "gloomLocker",
		lore = "I keep the Gloom in line. Mostly.",
	},
	{
		id = "Pippa.Bubbles",
		kind = "emote",
		employee = "Pippa",
		name = "Bubbles",
		rarity = "legendary",
		source = "gleam",
		price = 400,
		lore = "Watch them float away!",
	},

	-- Cappy
	{
		id = "Cappy.PJ",
		kind = "skin",
		employee = "Cappy",
		name = "PJ Cappy",
		rarity = "legendary",
		source = "gleam",
		price = 1500,
		styles = 3,
		bundle = { "Cappy.CocoaSip", "SleepySway", "CozyPack" },
		lore = "Who says you can't clean in your PJs? The shark slippers are for speed. Probably.",
	},
	{
		id = "Cappy.GloomTouched",
		kind = "skin",
		employee = "Cappy",
		name = "Gloom-Touched",
		rarity = "uncommon",
		source = "gloomLocker",
		lore = "It's just paint. It's fine.",
	},
	{
		id = "Cappy.GhostDebunker",
		kind = "skin",
		employee = "Cappy",
		name = "Ghost Debunker",
		rarity = "epic",
		source = "gloomLocker",
		lore = "Ghosts are not real. I have the gear to prove it.",
	},
	{
		id = "Cappy.CocoaSip",
		kind = "emote",
		employee = "Cappy",
		name = "Cocoa Sip",
		rarity = "legendary",
		source = "gleam",
		price = 400,
		lore = "A slow sip, a happy sigh. Ahh.",
	},

	-- Prickles
	{
		id = "Prickles.Sheriff",
		kind = "skin",
		employee = "Prickles",
		name = "Sheriff Prickles",
		rarity = "legendary",
		source = "gleam",
		price = 1500,
		styles = 3,
		bundle = { "Prickles.Lasso", "SheriffPack" },
		lore = "There's a new sheriff on the night shift.",
	},
	{
		id = "Prickles.GloomTouched",
		kind = "skin",
		employee = "Prickles",
		name = "Gloom-Touched",
		rarity = "uncommon",
		source = "gloomLocker",
		lore = "Purple is fine. I guess.",
	},
	{
		id = "Prickles.PotKnight",
		kind = "skin",
		employee = "Prickles",
		name = "Pot Knight",
		rarity = "epic",
		source = "gloomLocker",
		lore = "Armour made from a flower pot. Very brave.",
	},
	{
		id = "Prickles.Lasso",
		kind = "emote",
		employee = "Prickles",
		name = "Hose Lasso",
		rarity = "legendary",
		source = "gleam",
		price = 400,
		lore = "Yee-haw. Don't tell anyone I said that.",
	},

	-- Shared idles
	{
		id = "SleepySway",
		kind = "idle",
		name = "Sleepy Sway",
		rarity = "epic",
		source = "gleam",
		price = 400,
		lore = "Night shifts are long. A tiny nap standing up never hurt anybody.",
	},

	-- Sticker packs and their stickers
	{
		id = "CozyPack",
		kind = "stickerPack",
		name = "Cozy Pack",
		rarity = "rare",
		source = "gleam",
		price = 150,
		lore = "Stickers for a sleepy crew.",
	},
	{
		id = "CozyPack.Cocoa",
		kind = "sticker",
		pack = "CozyPack",
		name = "Cocoa",
		rarity = "rare",
		source = "gleam",
		lore = "Hot cocoa time.",
	},
	{
		id = "CozyPack.Sleepy",
		kind = "sticker",
		pack = "CozyPack",
		name = "Sleepy",
		rarity = "rare",
		source = "gleam",
		lore = "Five more minutes.",
	},
	{
		id = "CozyPack.Pillow",
		kind = "sticker",
		pack = "CozyPack",
		name = "Pillow",
		rarity = "rare",
		source = "gleam",
		lore = "Pillow fight later?",
	},
	{
		id = "BubblePack",
		kind = "stickerPack",
		name = "Bubble Pack",
		rarity = "rare",
		source = "gleam",
		price = 150,
		lore = "Stickers that float.",
	},
	{
		id = "BubblePack.Ducky",
		kind = "sticker",
		pack = "BubblePack",
		name = "Ducky",
		rarity = "rare",
		source = "gleam",
		lore = "Quack!",
	},
	{
		id = "BubblePack.Bubbles",
		kind = "sticker",
		pack = "BubblePack",
		name = "Bubbles",
		rarity = "rare",
		source = "gleam",
		lore = "Pop pop pop.",
	},
	{
		id = "BubblePack.Splash",
		kind = "sticker",
		pack = "BubblePack",
		name = "Splash",
		rarity = "rare",
		source = "gleam",
		lore = "Puddle jump!",
	},
	{
		id = "SheriffPack",
		kind = "stickerPack",
		name = "Sheriff Pack",
		rarity = "rare",
		source = "gleam",
		price = 150,
		lore = "Stickers for keeping order.",
	},
	{
		id = "SheriffPack.Badge",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Badge",
		rarity = "rare",
		source = "gleam",
		lore = "I'm in charge here.",
	},
	{
		id = "SheriffPack.Howdy",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Howdy",
		rarity = "rare",
		source = "gleam",
		lore = "Howdy, partner.",
	},
	{
		id = "SheriffPack.Grump",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Grump",
		rarity = "rare",
		source = "gleam",
		lore = "Not today.",
	},
}

local byId: { [string]: Item } = {}
local sorted: { Item } = {}
for _, item in ITEMS do
	assert(byId[item.id] == nil, `CosmeticRegistry: duplicate id {item.id}`)
	local frozen = table.freeze(item)
	byId[item.id] = frozen
	table.insert(sorted, frozen)
	if item.kind ~= "sticker" and not EntitlementRegistry.has(item.kind, item.id) then
		EntitlementRegistry.register(item.kind, item.id, { name = item.name })
	end
end
table.sort(sorted, function(a, b)
	return a.id < b.id
end)
table.freeze(sorted)

local CosmeticRegistry = {}

function CosmeticRegistry.get(id: string): Item?
	return byId[id]
end

function CosmeticRegistry.has(id: string): boolean
	return byId[id] ~= nil
end

-- Every item, sorted by id.
function CosmeticRegistry.all(): { Item }
	return sorted
end

--[=[
	The items of `kind`; with `employee`, only that employee's and the shared ones (employee nil).
]=]
function CosmeticRegistry.ofKind(kind: Kind, employee: string?): { Item }
	local list: { Item } = {}
	for _, item in sorted do
		if item.kind == kind and (employee == nil or item.employee == nil or item.employee == employee) then
			table.insert(list, item)
		end
	end
	return list
end

-- The employee ids, sorted.
function CosmeticRegistry.employees(): { string }
	local list: { string } = {}
	for _, item in sorted do
		if item.kind == "employee" then
			table.insert(list, item.id)
		end
	end
	return list
end

--[=[
	The employee's free item of `kind` (its Classic skin, idle or default emote). Errors when there is none: the
	registry spec guarantees one each.
]=]
function CosmeticRegistry.defaultOf(employee: string, kind: Kind): Item
	for _, item in sorted do
		if item.kind == kind and item.employee == employee and item.source == "default" then
			return item
		end
	end
	error(`CosmeticRegistry: {employee} has no default {kind}`)
end

return CosmeticRegistry
