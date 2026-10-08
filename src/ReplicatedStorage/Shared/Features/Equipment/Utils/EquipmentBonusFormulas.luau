--!strict
--[=[
	EquipmentBonusFormulas: pure aggregation of an equipped-gear wrapper's stat bonuses.

	Extracted out of `EquipmentServiceServer` (rather than left as a private helper there) so
	`StatServiceServer:getDerived` can fold equipment into a build WITHOUT requiring
	`EquipmentServiceServer` — `EquipmentServiceServer` already has a normal top-of-file require of
	`StatServiceServer` (its equip-time level check), so a require in the other direction, even one
	placed inside a function body to dodge the RUNTIME partial-module-table hazard, is still a genuine
	circular MODULE dependency that `luau-lsp`'s static analyzer rejects outright (it resolves every
	`require()` expression as a dependency edge regardless of where in the file it is textually
	placed — deferring the call to runtime does not defer the edge for type-checking purposes).

	This module has ZERO service dependencies (only `ItemRegistry`, a leaf), so both
	`EquipmentServiceServer` (which owns the typed `Equipment` value) and `StatServiceServer` (which
	reads it back off the already-mirrored `StateSyncServerStore` "equipment" slice, needing no service
	require at all — see `StatServiceServer.getDerived`) can call it with no cycle in either
	direction. `StatFormulas` is the same idiom: pure math both realms/services share.

	@class EquipmentBonusFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local ItemAffixConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemAffixConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

local EquipmentBonusFormulas = {}

--[=[
	Sums every equipped entry's `statBonuses`, keyed by StatConstants stat id — the modifier layer
	`StatFormulas.derive`'s `sources` parameter expects. `{}` if nothing is equipped or `equipment` is
	nil (never throws).
	@param equipment PlayerDataTypes.Equipment? -- The equipped-gear wrapper (nil if unloaded/unmirrored)
	@return { [string]: number } -- Summed bonuses, keyed by stat id
]=]
function EquipmentBonusFormulas.aggregate(equipment: PlayerDataTypes.Equipment?): { [string]: number }
	local bonuses: { [string]: number } = {}
	if not equipment then
		return bonuses
	end
	for _, entry in equipment.slots do
		local definition = ItemRegistry.get(entry.itemType)
		if not definition then
			continue
		end
		-- Narrowed via separate ifs (not a compound `and`/`or` condition) so the type checker can
		-- actually see `definition` down to WeaponDefinition | ArmourDefinition — the only variants
		-- with a `statBonuses` field.
		if definition.kind ~= "weapon" and definition.kind ~= "armour" then
			continue
		end
		-- WeaponDefinition.statBonuses and ArmourDefinition.statBonuses are declared with the
		-- IDENTICAL type ({ [string]: number }?), but Luau does not merge that field's type across
		-- the two union members after the kind-narrow above, so `for in` sees an unresolved union of
		-- two structurally-equal-but-distinct table types and refuses to iterate it. Casting to the
		-- one shared shape both members already declare is a legal same-shape narrowing (not a
		-- fabricated type), the same technique validateInventory documents for its StackEntry/
		-- UniqueEntry casts.
		-- Layer 1 — the definition's FIXED baseline bonus (every copy identical).
		local statBonuses = definition.statBonuses :: { [string]: number }? -- same-shape narrowing, see above
		if statBonuses then
			for statId, amount in statBonuses do
				bonuses[statId] = (bonuses[statId] or 0) + amount
			end
		end

		-- Layer 2 (Tier 1, RESERVED) — guaranteed base-stat rolls, keyed by stat id. nil on every entry
		-- until combat writes `statRolls`; folded now so combat is pure content, not an aggregate change.
		if entry.statRolls then
			for statId, amount in entry.statRolls do
				bonuses[statId] = (bonuses[statId] or 0) + amount
			end
		end

		-- Layer 3 (Tier 2, THIS PHASE) — the rolled pool affix. Map affixId -> stat, add the stored
		-- absolute value. A RETIRED affixId resolves to nil and is skipped (matches the slice
		-- validators' leniency / PoE disable-don't-delete) — never an error, just no contribution.
		if entry.affixes then
			for affixId, amount in entry.affixes do
				local affixDef = ItemAffixConstants.get(affixId)
				if affixDef then
					bonuses[affixDef.stat] = (bonuses[affixDef.stat] or 0) + amount
				end
			end
		end
	end
	return bonuses
end

return EquipmentBonusFormulas
