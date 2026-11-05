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
		id = "CozyPack.Whatever",
		kind = "sticker",
		pack = "CozyPack",
		name = "Whatever",
		rarity = "rare",
		source = "gleam",
		lore = "Cappy shrugs. It's whatever.",
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
		id = "CozyPack.CocoaBreak",
		kind = "sticker",
		pack = "CozyPack",
		name = "Cocoa Break",
		rarity = "rare",
		source = "gleam",
		lore = "Hot cocoa time.",
	},
	{
		id = "CozyPack.Facepalm",
		kind = "sticker",
		pack = "CozyPack",
		name = "Facepalm",
		rarity = "rare",
		source = "gleam",
		lore = "Oh no. Not again.",
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

return ITEMS
