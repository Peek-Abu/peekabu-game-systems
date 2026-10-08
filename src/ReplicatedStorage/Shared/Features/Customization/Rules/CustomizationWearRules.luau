--!strict
--[=[
	CustomizationWearRules: the PURE rule for whether a cosmetic may be worn with a given head type,
	and which equipped cosmetics a head-type switch would invalidate.

	Some cosmetics only work with one head mode — a hair authored to sit under a hood clips through an
	uncovered face, and vice versa. A cosmetic declares the modes it supports via its registry entry's
	`headTypes`; an ABSENT declaration means "works with both", so the default is permissive and only
	genuinely restricted content needs a row edit.

	This rule is enforced in TWO places, deliberately:
	- `CustomizationSliceRules` rejects an incompatible pair on ANY write path. Unlike the ownership
	  gate (which needs the account slice and therefore lives in the service), `cosmetics` and
	  `headType` are in the SAME slice, so the data-layer validator can see both — a strictly stronger
	  guarantee.
	- `CustomizationServiceServer:setHeadType` uses `find` to CLEAR offenders in the same mutation as
	  the head-type write, so switching your head never gets refused because of a hat (design spec,
	  Decision 3) and the validator never observes the invalid intermediate state.

	`find` takes an injectable `lookup` so the rule is unit-testable independently of which cosmetics
	the catalog restricts today — the real restrictions are authored in 5b's content pass.

	@class CustomizationWearRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

--[=[
	Resolves a cosmetic's declared head-type restriction, or nil when it has none (= works with both).
	@type HeadTypesLookup (category: string, id: string) -> { [string]: boolean }?
]=]
export type HeadTypesLookup = (category: string, id: string) -> { [string]: boolean }?

--[=[
	What a head-type switch would invalidate.
	@interface Incompatible
	.categories { string } -- single-selection categories to clear, sorted
	.accessoryIndices { number } -- accessory slots to remove, DESCENDING (see `find`)
]=]
export type Incompatible = {
	categories: { string },
	accessoryIndices: { number },
}

local ACCESSORY_CATEGORY = "accessory"

local CustomizationWearRules = {}

-- The registry-backed default lookup.
local function registryLookup(category: string, id: string): { [string]: boolean }?
	local entry = CustomizationCosmeticRegistry.get(category, id)
	return if entry then entry.headTypes else nil
end

--[=[
	Whether a restriction set permits `headType`. An absent set permits everything.
	@param headTypes { [string]: boolean }? -- the cosmetic's declared modes, or nil for unrestricted
	@param headType string
	@return boolean
]=]
function CustomizationWearRules.allows(headTypes: { [string]: boolean }?, headType: string): boolean
	if headTypes == nil then
		return true
	end
	return headTypes[headType] == true
end

--[=[
	Whether a registered cosmetic may be worn with `headType`. An UNREGISTERED id is treated as
	compatible — the same disable-don't-delete tolerance the rest of the system applies to retired ids,
	so a cosmetic removed from the catalog never makes an existing character un-saveable.
	@param category string
	@param id string
	@param headType string
	@return boolean
]=]
function CustomizationWearRules.isCompatible(category: string, id: string, headType: string): boolean
	return CustomizationWearRules.allows(registryLookup(category, id), headType)
end

--[=[
	Every equipped cosmetic that would be invalid under `headType`.

	`accessoryIndices` is DESCENDING on purpose: the caller removes them with `table.remove`, and
	removing a low index first would shift every later target down by one, silently clearing the wrong
	slot. Descending order makes sequential removal correct without the caller knowing why.

	`categories` is sorted so the reported set (and the reason string built from it) is deterministic.

	@param appearance PlayerDataTypes.Appearance
	@param headType string -- the head type being switched TO
	@param lookup HeadTypesLookup? -- defaults to the registry; injectable for tests
	@return Incompatible
]=]
function CustomizationWearRules.find(
	appearance: PlayerDataTypes.Appearance,
	headType: string,
	lookup: HeadTypesLookup?
): Incompatible
	-- Annotated: without it the `or` yields a union Luau refuses to call.
	local resolve: HeadTypesLookup = lookup or registryLookup
	local result: Incompatible = { categories = {}, accessoryIndices = {} }
	if type(appearance) ~= "table" then
		return result
	end

	if type(appearance.cosmetics) == "table" then
		for category, selection in appearance.cosmetics do
			if type(selection) == "table" and type(selection.id) == "string" then
				if not CustomizationWearRules.allows(resolve(category, selection.id), headType) then
					table.insert(result.categories, category)
				end
			end
		end
		table.sort(result.categories)
	end

	if type(appearance.accessories) == "table" then
		for index = #appearance.accessories, 1, -1 do
			local selection = appearance.accessories[index]
			if type(selection) == "table" and type(selection.id) == "string" then
				if not CustomizationWearRules.allows(resolve(ACCESSORY_CATEGORY, selection.id), headType) then
					table.insert(result.accessoryIndices, index)
				end
			end
		end
	end

	return result
end

--[=[
	The look a brand-new character starts with: a default cosmetic for every category that declares one
	under the standard head type, so nobody spawns bald. Seed this into each new slot's `appearance`.
	@return PlayerDataTypes.Appearance
]=]
function CustomizationWearRules.defaultAppearance(): PlayerDataTypes.Appearance
	local headType = CustomizationCosmeticRegistry.DEFAULT_HEAD_TYPE
	local cosmetics: { [string]: PlayerDataTypes.CosmeticSelection } = {}
	for _, category in CustomizationCosmeticRegistry.defaultedCategories() do
		local id = CustomizationCosmeticRegistry.defaultCosmetic(category, headType)
		if id then
			cosmetics[category] = { id = id, colors = {} }
		end
	end
	return { cosmetics = cosmetics, accessories = {}, body = {}, headType = headType, surfaces = {} }
end

--[=[
	Fills every EMPTY defaulted category for the appearance's current head type, mutating in place.

	The invariant this serves is the developer's call that bald/barefoot is never a resting state — and
	that has to hold for profiles that PRE-DATE a default, not only new ones: when `Boots1` became the
	shoes default, every existing profile had no shoes selection, and registration defaults only stamp
	NEW appearances. The service runs this on spawn (a no-op once filled) and inside `setHeadType`'s
	mutation, so the two paths cannot drift.

	@param appearance PlayerDataTypes.Appearance -- mutated in place, inside a data-layer mutation
	@param filled { string }? -- optional sink for "category -> id" lines, for the caller's reason string
	@return boolean -- whether anything was filled
]=]
function CustomizationWearRules.fillEmptyDefaults(appearance: PlayerDataTypes.Appearance, filled: { string }?): boolean
	local didFill = false
	for _, category in CustomizationCosmeticRegistry.defaultedCategories() do
		if appearance.cosmetics[category] == nil then
			local replacement = CustomizationCosmeticRegistry.defaultCosmetic(category, appearance.headType)
			if replacement then
				appearance.cosmetics[category] = { id = replacement, colors = {} }
				if filled then
					table.insert(filled, `{category} -> {replacement}`)
				end
				didFill = true
			end
		end
	end
	return didFill
end

return CustomizationWearRules
