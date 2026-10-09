--!strict
--[=[
	EntitlementRegistry: the ownable things by category and id (the ItemRegistry contract: validated, loud
	at boot, no re-registration). A game registers its catalogue at load:
	`EntitlementRegistry.register("suit", "hazmat", { name = "Hazmat Suit" })`.

	@class EntitlementRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EntitlementTypes = require(ReplicatedStorage.Shared.Features.Entitlement.Data.EntitlementTypes)
local EntitlementRules = require(ReplicatedStorage.Shared.Features.Entitlement.Rules.EntitlementRules)

type EntitlementDef = EntitlementTypes.EntitlementDef

local defs: { [string]: { [string]: EntitlementDef } } = {}

local EntitlementRegistry = {}

--[=[
	Registers `id` under `category`. Asserts: both are valid keys (EntitlementRules.isKey), the pair is
	new, and the definition has a name.
]=]
function EntitlementRegistry.register(category: string, id: string, def: EntitlementDef)
	assert(EntitlementRules.isKey(category), `entitlement category "{category}" must be 1-64 characters`)
	assert(EntitlementRules.isKey(id), `entitlement id "{id}" must be 1-64 characters`)
	assert(def.name ~= "", `entitlement {category}/{id} needs a name`)
	local ids = defs[category]
	if ids == nil then
		ids = {}
		defs[category] = ids
	end
	assert(ids[id] == nil, `entitlement {category}/{id} is already registered`)
	ids[id] = table.freeze(table.clone(def))
end

function EntitlementRegistry.get(category: string, id: string): EntitlementDef?
	local ids = defs[category]
	return if ids ~= nil then ids[id] else nil
end

function EntitlementRegistry.has(category: string, id: string): boolean
	return EntitlementRegistry.get(category, id) ~= nil
end

function EntitlementRegistry.idsIn(category: string): { string }
	local list: { string } = {}
	local ids = defs[category]
	if ids ~= nil then
		for id in ids do
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

function EntitlementRegistry.categories(): { string }
	local list: { string } = {}
	for category in defs do
		table.insert(list, category)
	end
	table.sort(list)
	return list
end

return EntitlementRegistry
