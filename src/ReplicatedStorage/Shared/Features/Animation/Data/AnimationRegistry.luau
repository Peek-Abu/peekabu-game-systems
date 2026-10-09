--!strict
--[=[
	AnimationRegistry: the composed index over the per-domain animation modules (Phase 6 spec,
	Decision 1). The ONE lookup surface — consumers (AnimationPlayerSystem, services, commands, enums)
	resolve every animation here and never require a domain module directly.

	Composition is PURE: the index is built by reading the domain modules, never by writing into
	them — the old registry's require-time `bothAnimations` merge is the anti-pattern this replaces.
	Malformed entries (non-canonical id, unknown class, duplicate key across domains) fail at
	compose time, i.e. at require, so a bad registry edit is caught by the first spec run or boot,
	not by the first play.

	Adding a domain (a future phase's Combat/Skills/Emotes/Npc module) = add the module file and one
	row in `DOMAIN_MODULES`.

	@class AnimationRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationShared = ReplicatedStorage.Shared.Features.Animation
local AnimationTypes = require(AnimationShared.Data.AnimationTypes)
local AnimationLocomotionRegistry = require(AnimationShared.Data.AnimationLocomotionRegistry)
local AnimationActionRegistry = require(AnimationShared.Data.AnimationActionRegistry)

type AnimationDef = AnimationTypes.AnimationDef
type AnimationDomain = AnimationTypes.AnimationDomain

--[=[
	The result of composing domain modules into one index.
	@interface ComposedIndex
	.byId { [string]: AnimationDef } -- entry key -> definition, across all domains
	.domainOf { [string]: string } -- entry key -> the domain that declared it
	.byWireId { [number]: string } -- replicable entries: wire id -> entry key
]=]
export type ComposedIndex = {
	byId: { [string]: AnimationDef },
	domainOf: { [string]: string },
	byWireId: { [number]: string },
}

-- Every registered domain. Future phases append here — nowhere else.
local DOMAIN_MODULES: { [string]: AnimationDomain } = table.freeze({
	locomotion = AnimationLocomotionRegistry,
	actions = AnimationActionRegistry,
})

-- The replicated-action fields (R3): a replicable entry carries a unique wire id and a layer, and a
-- one-shot declares its length; a local entry carries none of them. Throws on a violation.
local function checkReplication(key: string, def: AnimationDef, wireOwner: { [number]: string })
	if def.replicable ~= true then
		assert(
			def.wireId == nil and def.layer == nil and def.durationMs == nil,
			`[AnimationRegistry] "{key}" sets wireId/layer/durationMs but is not replicable`
		)
		return
	end
	local wireId = def.wireId
	if wireId == nil or wireId ~= math.floor(wireId) or wireId < 1 or wireId > AnimationTypes.MAX_WIRE_ID then
		error(`[AnimationRegistry] replicable "{key}" needs an integer wireId 1-{AnimationTypes.MAX_WIRE_ID}`)
	end
	local owner = wireOwner[wireId]
	assert(
		owner == nil,
		`[AnimationRegistry] wireId {wireId} is used by both "{owner}" and "{key}" — wire ids are unique and never reused`
	)
	wireOwner[wireId] = key
	assert(
		AnimationTypes.isAnimationLayer(def.layer),
		`[AnimationRegistry] replicable "{key}" declares unknown layer "{tostring(def.layer)}"`
	)
	local durationMs = def.durationMs
	if def.looped then
		assert(durationMs == nil, `[AnimationRegistry] looped "{key}" runs until stopped: omit durationMs`)
	elseif durationMs == nil or durationMs <= 0 then
		error(`[AnimationRegistry] replicable one-shot "{key}" must declare durationMs > 0`)
	end
	local variants = def.variants
	assert(
		variants == nil or #variants <= AnimationTypes.MAX_VARIANTS,
		`[AnimationRegistry] replicable "{key}" has more than {AnimationTypes.MAX_VARIANTS} variants`
	)
end

local AnimationRegistry = {}

--[=[
	Composes domain modules into one validated index. Exposed (rather than inlined) so the
	validation rules are unit-testable against fabricated domains; the module-level index below is
	this function applied to the real domains.

	Throws on: a key declared by two domains, a non-canonical asset or variant id, an unknown
	interruption class, or a malformed replicated-action field (see `checkReplication`).
	@param domains { [string]: AnimationDomain }
	@return ComposedIndex
]=]
function AnimationRegistry.composeDomains(domains: { [string]: AnimationDomain }): ComposedIndex
	local byId: { [string]: AnimationDef } = {}
	local domainOf: { [string]: string } = {}
	local byWireId: { [number]: string } = {}
	for domainName, domain in domains do
		for key, def in domain do
			assert(
				domainOf[key] == nil,
				`[AnimationRegistry] "{key}" is declared by both "{domainOf[key]}" and "{domainName}" — entry keys are unique across domains`
			)
			assert(
				AnimationTypes.isCanonicalAssetId(def.assetId),
				`[AnimationRegistry] "{key}" assetId "{def.assetId}" is not canonical rbxassetid://N`
			)
			assert(
				AnimationTypes.isInterruptionClass(def.interruption),
				`[AnimationRegistry] "{key}" declares unknown interruption class "{tostring(def.interruption)}"`
			)
			if def.variants ~= nil then
				local total = 0
				for _, variantId in def.variants do
					total += 1
					assert(
						AnimationTypes.isCanonicalAssetId(variantId),
						`[AnimationRegistry] "{key}" variant "{variantId}" is not canonical rbxassetid://N`
					)
				end
				-- Density: play-time variant rolling indexes 1..#variants, and `#` is undefined
				-- on tables with holes — prove the sequence here so it can't misroll later.
				assert(
					total == #def.variants,
					`[AnimationRegistry] "{key}" variants must be a dense array (no holes / non-sequential keys)`
				)
			end
			checkReplication(key, def, byWireId)
			byId[key] = def
			domainOf[key] = domainName
		end
	end
	return { byId = table.freeze(byId), domainOf = table.freeze(domainOf), byWireId = table.freeze(byWireId) }
end

local INDEX = AnimationRegistry.composeDomains(DOMAIN_MODULES)

local SORTED_IDS: { string } = {}
for key in INDEX.byId do
	table.insert(SORTED_IDS, key)
end
table.sort(SORTED_IDS)
table.freeze(SORTED_IDS)

--[=[
	Resolves an entry key to its definition.
	@param id string
	@return AnimationDef? -- nil when unregistered
]=]
function AnimationRegistry.get(id: string): AnimationDef?
	return INDEX.byId[id]
end

--[=[
	Names the domain that declared `id`.
	@param id string
	@return string? -- nil when unregistered
]=]
function AnimationRegistry.domainOf(id: string): string?
	return INDEX.domainOf[id]
end

--[=[
	A whole domain's entries, exactly as its module declares them.
	@param name string
	@return AnimationDomain? -- nil for an unknown domain
]=]
function AnimationRegistry.domain(name: string): AnimationDomain?
	return DOMAIN_MODULES[name]
end

--[=[
	Resolves a replicated action's wire id to its entry key.
	@param wireId number
	@return string? -- nil when no replicable entry has that id
]=]
function AnimationRegistry.idForWire(wireId: number): string?
	return INDEX.byWireId[wireId]
end

--[=[
	Every entry key across all domains, sorted — the Cmdr enum / UI list source.
	@return { string }
]=]
function AnimationRegistry.ids(): { string }
	return SORTED_IDS
end

return AnimationRegistry
