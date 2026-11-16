--!strict
--[=[
	CosmeticStickerRegistry: the sticker packs and their stickers (a sticker is owned through its pack). Part of
	CosmeticRegistry's catalogue, which looks every item up and registers its entitlement; the item shape and id rules
	are CosmeticRegistry's.

	@class CosmeticStickerRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)

local ITEMS: { CosmeticTypes.Item } = {
	-- Sticker packs and their stickers. A pack's rarity and price follow its sticker count (CosmeticConstants.STICKER_PACKS),
	-- and every sticker has its pack's rarity.
	{
		id = "CozyPack",
		kind = "stickerPack",
		name = "Cozy Pack",
		rarity = "epic",
		source = "gleam",
		price = 400,
		lore = "Stickers for a sleepy crew.",
	},
	{
		id = "CozyPack.Whatever",
		kind = "sticker",
		pack = "CozyPack",
		name = "Whatever",
		rarity = "epic",
		source = "gleam",
		lore = "Cappy shrugs. It's whatever.",
	},
	{
		id = "CozyPack.Sleepy",
		kind = "sticker",
		pack = "CozyPack",
		name = "Sleepy",
		rarity = "epic",
		source = "gleam",
		lore = "Five more minutes.",
	},
	{
		id = "CozyPack.CocoaBreak",
		kind = "sticker",
		pack = "CozyPack",
		name = "Cocoa Break",
		rarity = "epic",
		source = "gleam",
		lore = "Hot cocoa time.",
	},
	{
		id = "CozyPack.Facepalm",
		kind = "sticker",
		pack = "CozyPack",
		name = "Facepalm",
		rarity = "epic",
		source = "gleam",
		lore = "Oh no. Not again.",
	},
	{
		id = "BubblePack",
		kind = "stickerPack",
		name = "Bubble Pack",
		rarity = "epic",
		source = "gleam",
		price = 400,
		lore = "Stickers that float.",
	},
	{
		id = "BubblePack.Yay",
		kind = "sticker",
		pack = "BubblePack",
		name = "Yay!",
		rarity = "epic",
		source = "gleam",
		lore = "Pippa cheers in her duck float.",
	},
	{
		id = "BubblePack.ThankYou",
		kind = "sticker",
		pack = "BubblePack",
		name = "Thank You",
		rarity = "epic",
		source = "gleam",
		lore = "A heart bubble, just for you.",
	},
	{
		id = "BubblePack.UhOh",
		kind = "sticker",
		pack = "BubblePack",
		name = "Uh Oh",
		rarity = "epic",
		source = "gleam",
		lore = "Pippa hides in a bubble.",
	},
	{
		id = "BubblePack.GoodJob",
		kind = "sticker",
		pack = "BubblePack",
		name = "Good Job",
		rarity = "epic",
		source = "gleam",
		lore = "A thumbs up and a wink.",
	},
	{
		id = "SheriffPack",
		kind = "stickerPack",
		name = "Sheriff Pack",
		rarity = "epic",
		source = "gleam",
		price = 400,
		lore = "Stickers for keeping order.",
	},
	{
		id = "SheriffPack.Howdy",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Howdy",
		rarity = "epic",
		source = "gleam",
		lore = "Prickles tips his hat.",
	},
	{
		id = "SheriffPack.GotIt",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Got It!",
		rarity = "epic",
		source = "gleam",
		lore = "Yee-haw! The hose lasso spins.",
	},
	{
		id = "SheriffPack.Aww",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Aww",
		rarity = "epic",
		source = "gleam",
		lore = "A big softy with a flower.",
	},
	{
		id = "SheriffPack.Oops",
		kind = "sticker",
		pack = "SheriffPack",
		name = "Oops",
		rarity = "epic",
		source = "gleam",
		lore = "Prickles made a little mistake.",
	},

	-- The Thanksgiving event's pack (owner L4, 2026-11-16): sold for acorns only while the event is live (EventRegistry
	-- "harvest"); owners keep it after. Price is a placeholder until the owner sets prices (R4).
	{
		id = "HarvestPack",
		kind = "stickerPack",
		name = "Harvest Pack",
		rarity = "rare",
		source = "event",
		event = "harvest",
		price = 200,
		lore = "Fall stickers for a thankful crew.",
	},
	{
		id = "HarvestPack.Thanks",
		kind = "sticker",
		pack = "HarvestPack",
		name = "Thanks!",
		rarity = "rare",
		source = "event",
		event = "harvest",
		lore = "Pippa brought pie for everyone.",
	},
	{
		id = "HarvestPack.Cozy",
		kind = "sticker",
		pack = "HarvestPack",
		name = "Cozy",
		rarity = "rare",
		source = "event",
		event = "harvest",
		lore = "Cappy naps in a pile of leaves.",
	},
	{
		id = "HarvestPack.Yum",
		kind = "sticker",
		pack = "HarvestPack",
		name = "Yum!",
		rarity = "rare",
		source = "event",
		event = "harvest",
		lore = "Prickles found an acorn. Snack time!",
	},
}

return ITEMS
