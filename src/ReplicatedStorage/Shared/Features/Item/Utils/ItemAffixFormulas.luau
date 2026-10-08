--!strict
--[=[
	ItemAffixFormulas: the pure roll of a single per-instance affix onto a unique item, at mint time.

	Server-authoritative and rolled ONCE at mint (see `InventoryServiceServer.addUnique`); the result
	is stored immutably on the `UniqueEntry.affixes` map and never re-rolled or client-supplied. `random`
	is INJECTED (not created here) so specs pass a seeded `Random.new(seed)` for deterministic
	assertions while production passes a live `Random.new()` — the same reason `StatFormulas` takes its
	inputs rather than reading global state.

	Roll model (affix-rolling design spec, Decision 2/5): one affix slot per item, filled
	probabilistically. A FLAT, rarity-independent DROP roll (ItemAffixConstants.AFFIX_CHANCE) decides
	whether the item gets its affix at all; on a hit, one affixId is picked uniformly from the item
	kind's pool and its value rolled uniformly in the affix's integer range. At most one affix (the
	field is a map, so widening to several later is a roller change, not a schema change).

	@class ItemAffixFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local ItemAffixConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemAffixConstants)

local ItemAffixFormulas = {}

--[=[
	Rolls this item's single affix slot, or returns nil when nothing drops (no pool for the kind, or the
	rarity's drop roll missed) — nil so the stored `affixes` field simply stays absent.
	@param itemType string -- The internal item definition key being minted
	@param random Random -- Injected RNG stream (seeded in tests, live in production)
	@return { [string]: number }? -- A single-entry { [affixId]: rolledValue } map, or nil
]=]
function ItemAffixFormulas.roll(itemType: string, random: Random): { [string]: number }?
	local definition = ItemRegistry.get(itemType)
	if not definition then
		return nil
	end

	local pool = ItemAffixConstants.POOLS[definition.kind]
	if not pool then
		return nil
	end

	-- Flat drop roll — rarity-independent (see ItemAffixConstants.AFFIX_CHANCE).
	if random:NextNumber() >= ItemAffixConstants.AFFIX_CHANCE then
		return nil
	end

	-- Collect the pool's affixIds into a SORTED array so a seeded stream picks reproducibly (map
	-- iteration order is not guaranteed). The load-time asserts in ItemAffixConstants guarantee the pool is
	-- non-empty, so the NextInteger below always has a valid range.
	local affixIds: { string } = {}
	for affixId in pool do
		table.insert(affixIds, affixId)
	end
	table.sort(affixIds)

	local pickedId = affixIds[random:NextInteger(1, #affixIds)]
	local affixDef = pool[pickedId]
	local value = random:NextInteger(affixDef.min, affixDef.max)
	return { [pickedId] = value }
end

return ItemAffixFormulas
