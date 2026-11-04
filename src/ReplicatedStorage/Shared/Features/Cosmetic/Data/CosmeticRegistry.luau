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
		lore = "Pippa's favourite bow and her lucky bell. She never cleans without them.",
	},
	{
		id = "Cappy.Default",
		kind = "skin",
		employee = "Cappy",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "A comfy hoodie and a cap on backwards. Cappy is ready for anything.",
	},
	{
		id = "Prickles.Default",
		kind = "skin",
		employee = "Prickles",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "A hard hat with a flower on top. Prickles is ready to work.",
	},
	{
		id = "Pippa.Classic",
		kind = "idle",
		employee = "Pippa",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "Pippa can't stand still. She bounces, always.",
	},
	{
		id = "Cappy.Classic",
		kind = "idle",
		employee = "Cappy",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "Hands in his pocket. Cappy is totally chill.",
	},
	{
		id = "Prickles.Classic",
		kind = "idle",
		employee = "Prickles",
		name = "Classic",
		rarity = "default",
		source = "default",
		lore = "Arms crossed. Prickles is not impressed.",
	},
	{
		id = "Pippa.Wave",
		kind = "emote",
		employee = "Pippa",
		name = "One-Paw Wave",
		rarity = "default",
		source = "default",
		lore = "Hi, crew! Over here!",
		quote = true,
	},
	{
		id = "Cappy.FistBump",
		kind = "emote",
		employee = "Cappy",
		name = "Shrug",
		rarity = "default",
		source = "default",
		lore = "Eh. Who knows?",
		quote = true,
	},
	{
		id = "Prickles.Huff",
		kind = "emote",
		employee = "Prickles",
		name = "Grumpy Fist Pump",
		rarity = "default",
		source = "default",
		lore = "Prickles pumps his fist. He is grumpy, but he is ready!",
	},

	-- Pippa
	{
		id = "Pippa.OwnerSpecial",
		kind = "skin",
		employee = "Pippa",
		name = "Lavender Specs",
		rarity = "rare",
		source = "gift",
		lore = "A gift from the boss: lavender fur and very fancy glasses.",
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
		lore = "Rain or shine, Pippa thinks bubbles make cleaning fun.",
	},
	{
		id = "Pippa.GloomTouched",
		kind = "skin",
		employee = "Pippa",
		name = "Gloom-Touched",
		rarity = "uncommon",
		source = "gloomLocker",
		lore = "Pippa stepped in the purple stuff, and now it's all over her. Oops.",
	},
	{
		id = "Pippa.Gloomkeeper",
		kind = "skin",
		employee = "Pippa",
		name = "Gloomkeeper",
		rarity = "epic",
		source = "gloomLocker",
		lore = "Pippa keeps the Gloom in line. Mostly.",
	},
	{
		id = "Pippa.Bubbles",
		kind = "emote",
		employee = "Pippa",
		name = "Bubble Ride",
		rarity = "legendary",
		source = "gleam",
		price = 400,
		lore = "Pippa blows one giant bubble and floats away inside it. Pop!",
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
		lore = "Cappy cleans in his PJs. He says the shark slippers are for speed. Probably.",
	},
	{
		id = "Cappy.GloomTouched",
		kind = "skin",
		employee = "Cappy",
		name = "Gloom-Touched",
		rarity = "uncommon",
		source = "gloomLocker",
		lore = "Cappy got Gloom all over him. He says it's just paint.",
	},
	{
		id = "Cappy.GhostDebunker",
		kind = "skin",
		employee = "Cappy",
		name = "Ghost Debunker",
		rarity = "epic",
		source = "gloomLocker",
		lore = "Ghosts are not real. I have the gear to prove it.",
		quote = true,
	},
	{
		id = "Cappy.CocoaSip",
		kind = "emote",
		employee = "Cappy",
		name = "Cocoa Sip",
		rarity = "legendary",
		source = "gleam",
		price = 400,
		lore = "A slow sip of cocoa, then a happy sigh. Ahh.",
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
		lore = "There's a new sheriff on the night shift, and he is very prickly.",
	},
	{
		id = "Prickles.GloomTouched",
		kind = "skin",
		employee = "Prickles",
		name = "Gloom-Touched",
		rarity = "uncommon",
		source = "gloomLocker",
		lore = "Prickles got covered in Gloom. Purple is fine, he guesses.",
	},
	{
		id = "Prickles.PotKnight",
		kind = "skin",
		employee = "Prickles",
		name = "Pot Knight",
		rarity = "epic",
		source = "gloomLocker",
		lore = "Armour made from a flower pot. Prickles is very brave.",
	},
	{
		id = "Prickles.Lasso",
		kind = "emote",
		employee = "Prickles",
		name = "Big Roundup",
		rarity = "legendary",
		source = "gleam",
		price = 400,
		lore = "Spin it, throw it, yank it back. Yee-haw!",
		quote = true,
	},

	-- Vacuums (one for the whole crew; the part after the dot is the VacuumSkinRegistry skin)
	{
		id = "Vacuum.StandardIssue",
		kind = "vacuum",
		name = "Standard Issue",
		rarity = "default",
		source = "default",
		lore = "The company vacuum. It is teal, it is loud, and it never gives up.",
	},
	{
		id = "Vacuum.BrassBellows",
		kind = "vacuum",
		name = "Brass Bellows",
		rarity = "rare",
		source = "gleam",
		price = 600,
		lore = "A brass vacuum under a glass dome. Nobody knows how old it is. The gauges still work. Mostly.",
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
		id = "BubblePack.Yay",
		kind = "sticker",
		pack = "BubblePack",
		name = "Yay!",
		rarity = "rare",
		source = "gleam",
		lore = "Pippa cheers in her duck float.",
	},
	{
		id = "BubblePack.ThankYou",
		kind = "sticker",
		pack = "BubblePack",
		name = "Thank You",
		rarity = "rare",
		source = "gleam",
		lore = "A heart bubble, just for you.",
	},
	{
		id = "BubblePack.UhOh",
		kind = "sticker",
		pack = "BubblePack",
		name = "Uh Oh",
		rarity = "rare",
		source = "gleam",
		lore = "Pippa hides in a bubble.",
	},
	{
		id = "BubblePack.GoodJob",
		kind = "sticker",
		pack = "BubblePack",
		name = "Good Job",
		rarity = "rare",
		source = "gleam",
		lore = "A thumbs up and a wink.",
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
		id = "SheriffPack.Howdy",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Howdy",
		rarity = "rare",
		source = "gleam",
		lore = "Prickles tips his hat.",
	},
	{
		id = "SheriffPack.GotIt",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Got It!",
		rarity = "rare",
		source = "gleam",
		lore = "Yee-haw! The hose lasso spins.",
	},
	{
		id = "SheriffPack.Aww",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Aww",
		rarity = "rare",
		source = "gleam",
		lore = "A big softy with a flower.",
	},
	{
		id = "SheriffPack.Oops",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Oops",
		rarity = "rare",
		source = "gleam",
		lore = "Prickles made a little mistake.",
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

local CosmeticRegistry = {
	-- Everyone's vacuum until they wear another.
	DEFAULT_VACUUM = "Vacuum.StandardIssue",
}

-- The art key after an id's first dot ("Pippa.OwnerSpecial" -> "OwnerSpecial", "Vacuum.BrassBellows" ->
-- "BrassBellows"); an id with no dot is its own key.
function CosmeticRegistry.keyOf(id: string): string
	return string.match(id, "^[^%.]+%.(.+)$") or id
end

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
