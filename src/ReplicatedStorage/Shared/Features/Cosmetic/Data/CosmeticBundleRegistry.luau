--!strict
--[=[
	CosmeticBundleRegistry: the bundles, items sold together (owner, 2026-11-13: skins, emotes, sticker packs, idles and
	vacuum skins are each their own item; a bundle groups them and can mix employees and kinds). Buying a bundle grants
	every item in it; owning a bundle only means owning all its items, so nothing about a bundle is saved and a retired
	bundle needs no migration. The Shop promotes a skin's bundle over the skin alone (ShopRegistry).

	Ids are `Bundle.<Name>`, never a CosmeticRegistry id. Prices are first drafts: the Shop's price rules (sales, what a
	bundle costs when you own part of it) are the Shop's, read from here and from each item's own price.

	@class CosmeticBundleRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)

type Bundle = CosmeticTypes.Bundle

local BUNDLES: { Bundle } = {
	-- The Legendary skins' bundles: the skin, its emote and its sticker pack (what buying the skin gave before the
	-- split). Owner, 11-13 (price sheet Q3): a bundle is 30% off its items alone, rounded down to 10
	-- (1,200 + 400 + 150 = 1,750 -> 1,220).
	{
		id = "Bundle.BubbleBuddy",
		name = "Bubble Buddy Bundle",
		rarity = "legendary",
		items = { "Pippa.BubbleBuddy", "Pippa.Bubbles", "BubblePack" },
		currency = "gleam",
		price = 1220,
		lore = "Everything for a bubbly day: the skin, the Bubbles emote and the sticker pack.",
	},
	{
		id = "Bundle.PJCappy",
		name = "PJ Cappy Bundle",
		rarity = "legendary",
		items = { "Cappy.PJ", "Cappy.CocoaSip", "CozyPack" },
		currency = "gleam",
		price = 1220,
		lore = "Everything for a cozy night: the PJs, the Cocoa Sip emote and the sticker pack.",
	},
	{
		id = "Bundle.SheriffPrickles",
		name = "Sheriff Prickles Bundle",
		rarity = "legendary",
		items = { "Prickles.Sheriff", "Prickles.Lasso", "SheriffPack" },
		currency = "gleam",
		price = 1220,
		lore = "Everything a sheriff needs: the skin, the Lasso emote and the sticker pack.",
	},
}

local byId: { [string]: Bundle } = {}
local sorted: { Bundle } = {}
for _, bundle in BUNDLES do
	assert(byId[bundle.id] == nil, `CosmeticBundleRegistry: duplicate id {bundle.id}`)
	assert(not CosmeticRegistry.has(bundle.id), `CosmeticBundleRegistry: {bundle.id} is a catalogue id`)
	for _, id in bundle.items do
		local item = CosmeticRegistry.get(id)
		assert(item ~= nil, `CosmeticBundleRegistry: {bundle.id} holds unknown item {id}`)
		assert(item.kind ~= "sticker", `CosmeticBundleRegistry: {bundle.id} holds a sticker ({id}); add its pack`)
		assert(item.source ~= "default", `CosmeticBundleRegistry: {bundle.id} holds the free {id}`)
	end
	table.freeze(bundle.items)
	local frozen = table.freeze(bundle)
	byId[bundle.id] = frozen
	table.insert(sorted, frozen)
end
table.sort(sorted, function(a, b)
	return a.id < b.id
end)
table.freeze(sorted)

local CosmeticBundleRegistry = {}

function CosmeticBundleRegistry.get(id: string): Bundle?
	return byId[id]
end

function CosmeticBundleRegistry.has(id: string): boolean
	return byId[id] ~= nil
end

-- Every bundle, sorted by id.
function CosmeticBundleRegistry.all(): { Bundle }
	return sorted
end

-- The bundles that hold `itemId`, sorted by id.
function CosmeticBundleRegistry.containing(itemId: string): { Bundle }
	local list: { Bundle } = {}
	for _, bundle in sorted do
		if table.find(bundle.items, itemId) ~= nil then
			table.insert(list, bundle)
		end
	end
	return list
end

return CosmeticBundleRegistry
