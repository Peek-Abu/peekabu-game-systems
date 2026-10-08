--!strict
--[=[
	CustomizationEntitlementRules: may this player wear this cosmetic?

	The ownership gate every equip path runs before it writes. Pure: the caller hands in the player's
	entitlements and the category's unlock scope, so the rule needs no profile and no service, and both
	slices meet here without either slice validator seeing the other (a per-slice validator only ever
	sees its own value). A FREE cosmetic always passes: only lockable ids are ever stored as
	entitlements. Moved out of CustomizationServiceServer (issue #37): "is it allowed?" is a Rules job.

	@class CustomizationEntitlementRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

--[=[
	Where a cosmetic category's UNLOCKS live. Every category is account-wide today; the indirection is
	the extensibility seam the developer asked for (design spec, Decision 1a): flipping a category to
	"slot" later means adding a per-slot entitlement store and changing one row in the service's
	scope table, and this gate already routes through the scope.
	@type EntitlementScope "account" | "slot"
]=]
export type EntitlementScope = "account" | "slot"

local CustomizationEntitlementRules = {}

--[=[
	Whether `id` in `category` is unlocked for a player with `entitlements`.
	@param entitlements PlayerDataTypes.Entitlements? -- nil when no profile is loaded
	@param scope EntitlementScope -- where this category's unlocks live
	@param category string
	@param id string
	@return (boolean, string?) -- (ok, reason)
]=]
function CustomizationEntitlementRules.isUnlocked(
	entitlements: PlayerDataTypes.Entitlements?,
	scope: EntitlementScope,
	category: string,
	id: string
): (boolean, string?)
	if not CustomizationCosmeticRegistry.isLockable(category, id) then
		return true
	end
	if scope ~= "account" then
		-- Reached only once a category is deliberately flipped to per-slot; refusing loudly beats
		-- silently consulting the wrong store and handing out a cosmetic the player has not earned.
		return false, `entitlement scope "{scope}" for category "{category}" is not implemented yet`
	end
	if not entitlements then
		return false, "no profile loaded"
	end
	local owned = entitlements.cosmetics[category]
	if not owned or owned[id] ~= true then
		return false, `"{id}" is locked — unlock it before equipping`
	end
	return true
end

--[=[
	The pre-flight for every equip path: the id must be registered in its category AND unlocked.
	@param entitlements PlayerDataTypes.Entitlements?
	@param scope EntitlementScope
	@param category string
	@param id string
	@return (boolean, string?) -- (ok, reason)
]=]
function CustomizationEntitlementRules.canEquip(
	entitlements: PlayerDataTypes.Entitlements?,
	scope: EntitlementScope,
	category: string,
	id: string
): (boolean, string?)
	if not CustomizationCosmeticRegistry.isRegistered(category, id) then
		return false, `"{id}" is not a registered {category} cosmetic`
	end
	return CustomizationEntitlementRules.isUnlocked(entitlements, scope, category, id)
end

return CustomizationEntitlementRules
