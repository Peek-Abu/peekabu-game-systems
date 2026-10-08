--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemShared = ReplicatedStorage.Shared.Features.Item
local ItemAffixFormulas = require(ItemShared.Utils.ItemAffixFormulas)
local ItemAffixConstants = require(ItemShared.Data.ItemAffixConstants)
local ItemRegistry = require(ItemShared.Data.ItemRegistry)

-- Upper bound on `samples`: this command has no downstream service to validate its inputs, so it is
-- the boundary (per the project's boundary-validation rule). `samples` drives BOTH a loop and an
-- output-string build, so an unbounded value would hitch the server / balloon memory — clamp it.
local MAX_SAMPLES = 100

-- Read-only designer tool: rolls `samples` affixes for `itemType` and reports the outcomes so a
-- pool/chance/range change can be eyeballed without minting real items. Mints nothing, mutates nothing.
return function(_context, itemType: string, samples: number)
	if not ItemRegistry.isValidItemType(itemType) then
		return `Unknown itemType "{itemType}".`
	end
	local count = math.clamp(math.floor(samples), 1, MAX_SAMPLES)

	local random = Random.new()
	local lines: { string } = { `Affix roll preview for "{itemType}" ({count} samples):` }
	local hits = 0
	for i = 1, count do
		local rolled = ItemAffixFormulas.roll(itemType, random)
		if rolled then
			hits += 1
			for affixId, value in rolled do
				local def = ItemAffixConstants.get(affixId)
				local name = if def then def.displayName else affixId
				local stat = if def then def.stat else "?"
				table.insert(lines, `  {i}: {name} ({stat} +{value})`)
			end
		else
			table.insert(lines, `  {i}: (no affix)`)
		end
	end
	table.insert(lines, `{hits}/{count} rolled an affix.`)
	return table.concat(lines, "\n")
end
