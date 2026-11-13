--!strict
--[=[
	CosmeticEmployeeRegistry: the employees, their free defaults (one skin, idle and emote each) and each employee's
	own skins and emotes. Part of CosmeticRegistry's catalogue, which looks every item up and registers its
	entitlement; the item shape and id rules are CosmeticRegistry's.

	@class CosmeticEmployeeRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)

local ITEMS: { CosmeticTypes.Item } = {
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
		-- The free idle is whatever the worn skin does (owner, 2026-11-13): her bounce, or a Legendary skin's own.
		name = "Skin's Own",
		rarity = "default",
		source = "default",
		lore = "Pippa can't stand still. She bounces, or does what her skin does.",
	},
	{
		id = "Cappy.Classic",
		kind = "idle",
		employee = "Cappy",
		name = "Skin's Own",
		rarity = "default",
		source = "default",
		lore = "Hands in his pocket, or what his skin does. Cappy is totally chill.",
	},
	{
		id = "Prickles.Classic",
		kind = "idle",
		employee = "Prickles",
		name = "Skin's Own",
		rarity = "default",
		source = "default",
		lore = "Arms crossed, or what his skin does. Prickles is not impressed.",
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
		price = 1200,
		styles = 3,
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
		source = "later",
		-- Out of the Gloom Locker until it has art (owner, 2026-11-04); the id stays so owners keep it.
		lore = "Pippa keeps the Gloom in line. Mostly.",
	},
	{
		id = "Pippa.BellJester",
		kind = "skin",
		employee = "Pippa",
		name = "Bell Jester",
		rarity = "epic",
		source = "gloomLocker",
		lore = "Bells on her cape and bells on her toes. You can hear Pippa coming!",
	},
	{
		id = "Pippa.Bubbles",
		kind = "emote",
		employee = "Pippa",
		name = "Bubble Ride",
		-- Epic, not Legendary (owner, 2026-11-12): only the skins are Legendary.
		rarity = "epic",
		source = "gleam",
		price = 400,
		lore = "Pippa blows one giant bubble and floats away inside it. Pop!",
	},
	-- Bubble Buddy's idle as its own item (owner, 2026-11-13): her paws on the duck ring the Bubble Buddy outfit wears,
	-- so it fits that skin only until the duck ring is a prop every skin can show.
	{
		id = "Pippa.BubbleBuddyIdle",
		kind = "idle",
		employee = "Pippa",
		name = "Bubble Buddy Idle",
		rarity = "epic",
		source = "gleam",
		price = 400,
		fits = { "Pippa.BubbleBuddy" },
		lore = "Pippa floats in her duck ring, ready for a splash.",
	},

	-- Cappy
	{
		id = "Cappy.PJ",
		kind = "skin",
		employee = "Cappy",
		name = "PJ Cappy",
		rarity = "legendary",
		source = "gleam",
		price = 1200,
		styles = 3,
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
		source = "later",
		-- Out of the Gloom Locker until it has art (owner, 2026-11-04); the id stays so owners keep it.
		lore = "Ghosts are not real. I have the gear to prove it.",
		quote = true,
	},
	{
		id = "Cappy.Backstage",
		kind = "skin",
		employee = "Cappy",
		name = "Backstage",
		rarity = "epic",
		source = "gloomLocker",
		lore = "A tailcoat, a big bow and an ace on his cap. Cappy runs the show from behind the curtain.",
	},
	{
		id = "Cappy.CocoaSip",
		kind = "emote",
		employee = "Cappy",
		name = "Cocoa Sip",
		-- Epic, not Legendary (owner, 2026-11-12): only the skins are Legendary.
		rarity = "epic",
		source = "gleam",
		price = 400,
		lore = "A slow sip of cocoa, then a happy sigh. Ahh.",
	},
	-- PJ Cappy's idle as its own item (owner, 2026-11-13): the pillow he naps on is the PJ outfit's, so it fits that skin
	-- only until the pillow is a prop every skin can show.
	{
		id = "Cappy.PJIdle",
		kind = "idle",
		employee = "Cappy",
		name = "PJ Idle",
		rarity = "epic",
		source = "gleam",
		price = 400,
		fits = { "Cappy.PJ" },
		lore = "Cappy hugs his pillow and naps standing up.",
	},

	-- Prickles
	{
		id = "Prickles.Sheriff",
		kind = "skin",
		employee = "Prickles",
		name = "Sheriff Prickles",
		rarity = "legendary",
		source = "gleam",
		price = 1200,
		styles = 3,
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
		source = "later",
		-- Out of the Gloom Locker until it has art (owner, 2026-11-04); the id stays so owners keep it.
		lore = "Armour made from a flower pot. Prickles is very brave.",
	},
	{
		id = "Prickles.Showstopper",
		kind = "skin",
		employee = "Prickles",
		name = "Showstopper",
		rarity = "epic",
		source = "gloomLocker",
		lore = "A top hat, a fancy coat and a big scowl. The show starts now.",
	},
	{
		id = "Prickles.Lasso",
		kind = "emote",
		employee = "Prickles",
		name = "Big Roundup",
		-- Epic, not Legendary (owner, 2026-11-12): only the skins are Legendary.
		rarity = "epic",
		source = "gleam",
		price = 400,
		lore = "Spin it, throw it, yank it back. Yee-haw!",
		quote = true,
	},
	-- Sheriff Prickles' idle as its own item (owner, 2026-11-13): the hose coil is an emote prop every skin can show, so
	-- it fits every Prickles skin.
	{
		id = "Prickles.SheriffIdle",
		kind = "idle",
		employee = "Prickles",
		name = "Sheriff Idle",
		rarity = "epic",
		source = "gleam",
		price = 400,
		lore = "Prickles spins his hose like a rope. Yee-haw!",
	},
}

return ITEMS
