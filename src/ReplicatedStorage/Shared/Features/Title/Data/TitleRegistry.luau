--!strict
--[=[
	TitleRegistry: the composed index over the per-domain title modules (titles design spec,
	Decision 1). The ONE lookup surface — services, commands, enums, and future display consumers
	resolve every title here and never require a domain module directly.

	Composition is PURE: the index is built by reading the domain modules, never by writing into
	them (the same rule AnimationRegistry states). Malformed entries fail at compose time — at
	require, so a bad registry edit is caught by the first spec run or boot, not by the first award.

	Adding a domain = add the module file and one row in `DOMAIN_MODULES`.

	@class TitleRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleTypes = require(ReplicatedStorage.Shared.Features.Title.Data.TitleTypes)
local TitleGeneralRegistry = require(ReplicatedStorage.Shared.Features.Title.Data.TitleGeneralRegistry)

type TitleDef = TitleTypes.TitleDef
type TitleDomain = TitleTypes.TitleDomain

--[=[
	The result of composing domain modules into one index.
	@interface ComposedIndex
	.byId { [string]: TitleDef } -- entry key -> definition, across all domains
	.domainOf { [string]: string } -- entry key -> the domain that declared it
]=]
export type ComposedIndex = {
	byId: { [string]: TitleDef },
	domainOf: { [string]: string },
}

-- Every registered domain. Future phases append here — nowhere else.
local DOMAIN_MODULES: { [string]: TitleDomain } = table.freeze({
	general = TitleGeneralRegistry,
})

local TitleRegistry = {}

--[=[
	Composes domain modules into one validated index. Exposed (rather than inlined) so the
	validation rules are unit-testable against fabricated domains; the module-level index below is
	this function applied to the real domains.

	Throws on: a key declared by two domains, an entry whose `id` differs from its key, an empty
	displayName, or a non-Color3 color.
	@param domains { [string]: TitleDomain }
	@return ComposedIndex
]=]
function TitleRegistry.composeDomains(domains: { [string]: TitleDomain }): ComposedIndex
	local byId: { [string]: TitleDef } = {}
	local domainOf: { [string]: string } = {}
	for domainName, domain in domains do
		for key, def in domain do
			assert(
				domainOf[key] == nil,
				`[TitleRegistry] "{key}" is declared by both "{domainOf[key]}" and "{domainName}" — entry keys are unique across domains`
			)
			assert(
				def.id == key,
				`[TitleRegistry] "{key}" carries mismatched id "{def.id}" — an entry's id must equal its registry key`
			)
			assert(
				type(def.displayName) == "string" and def.displayName ~= "",
				`[TitleRegistry] "{key}" must carry a non-empty displayName`
			)
			assert(
				typeof(def.color) == "Color3",
				`[TitleRegistry] "{key}" color must be a Color3, got {typeof(def.color)}`
			)
			byId[key] = def
			domainOf[key] = domainName
		end
	end
	return { byId = table.freeze(byId), domainOf = table.freeze(domainOf) }
end

local INDEX = TitleRegistry.composeDomains(DOMAIN_MODULES)

local SORTED_IDS: { string } = {}
for key in INDEX.byId do
	table.insert(SORTED_IDS, key)
end
table.sort(SORTED_IDS)
table.freeze(SORTED_IDS)

--[=[
	Resolves a title id to its definition.
	@param id string
	@return TitleDef? -- nil when unregistered
]=]
function TitleRegistry.get(id: string): TitleDef?
	return INDEX.byId[id]
end

--[=[
	Names the domain that declared `id`.
	@param id string
	@return string? -- nil when unregistered
]=]
function TitleRegistry.domainOf(id: string): string?
	return INDEX.domainOf[id]
end

--[=[
	A whole domain's entries, exactly as its module declares them.
	@param name string
	@return TitleDomain? -- nil for an unknown domain
]=]
function TitleRegistry.domain(name: string): TitleDomain?
	return DOMAIN_MODULES[name]
end

--[=[
	True iff `id` names a registered title. The gate every WRITE path asserts against
	(TitleServiceServer award/revoke/equip): awarding or equipping a dead id is programmer error.
	Read paths must NOT use this as a filter — slice validators tolerate retired ids by design.
	@param id string
	@return boolean
]=]
function TitleRegistry.isValidTitleId(id: string): boolean
	return INDEX.byId[id] ~= nil
end

--[=[
	Every registered title id, sorted and frozen — the Cmdr enum source (`Shared/CmdrTypes/titleId`)
	and any future UI list.
	@return { string }
]=]
function TitleRegistry.getAllIds(): { string }
	return SORTED_IDS
end

return TitleRegistry
