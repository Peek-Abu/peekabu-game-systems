--!strict
--[=[
	CosmeticCollectionRegistry: named groups of items, broader than bundles and data only for launch (owner, 2026-11-13:
	not shown to players, not sold). A collection can mix employees and kinds; each Legendary set is one too, so its
	skin, emote and sticker pack stay linked even if its bundle is retired.

	Ids are `Collection.<Name>`.

	@class CosmeticCollectionRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)

type Collection = CosmeticTypes.Collection

local COLLECTIONS: { Collection } = {
	{
		id = "Collection.GloomTouched",
		name = "Gloom-Touched",
		items = { "Pippa.GloomTouched", "Cappy.GloomTouched", "Prickles.GloomTouched" },
	},
	-- The Legendary sets (coordinator's suggestion on the owner's idea, 2026-11-13; drop these three if the owner says
	-- no).
	{
		id = "Collection.BubbleBuddy",
		name = "Bubble Buddy",
		items = { "Pippa.BubbleBuddy", "Pippa.Bubbles", "BubblePack" },
	},
	{
		id = "Collection.PJCappy",
		name = "PJ Cappy",
		items = { "Cappy.PJ", "Cappy.CocoaSip", "CozyPack" },
	},
	{
		id = "Collection.SheriffPrickles",
		name = "Sheriff Prickles",
		items = { "Prickles.Sheriff", "Prickles.Lasso", "SheriffPack" },
	},
}

local byId: { [string]: Collection } = {}
local sorted: { Collection } = {}
for _, collection in COLLECTIONS do
	assert(byId[collection.id] == nil, `CosmeticCollectionRegistry: duplicate id {collection.id}`)
	for _, id in collection.items do
		assert(CosmeticRegistry.has(id), `CosmeticCollectionRegistry: {collection.id} holds unknown item {id}`)
	end
	table.freeze(collection.items)
	local frozen = table.freeze(collection)
	byId[collection.id] = frozen
	table.insert(sorted, frozen)
end
table.sort(sorted, function(a, b)
	return a.id < b.id
end)
table.freeze(sorted)

local CosmeticCollectionRegistry = {}

function CosmeticCollectionRegistry.get(id: string): Collection?
	return byId[id]
end

-- Every collection, sorted by id.
function CosmeticCollectionRegistry.all(): { Collection }
	return sorted
end

-- The collections that hold `itemId`, sorted by id.
function CosmeticCollectionRegistry.containing(itemId: string): { Collection }
	local list: { Collection } = {}
	for _, collection in sorted do
		if table.find(collection.items, itemId) ~= nil then
			table.insert(list, collection)
		end
	end
	return list
end

return CosmeticCollectionRegistry
