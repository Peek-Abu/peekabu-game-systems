--!strict
--[=[
	EntitlementRules: pure ownership logic over the `entitlements` slice, shared by both realms. Writers
	mutate in place (the data layer's mutator contract) and return whether anything changed.

	`validate` is the data-layer invariant: structure only (1-64 character category and id keys, `true`
	values). Unknown ids are deliberately allowed so retiring one never needs a migration.

	@class EntitlementRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

type Entitlements = PlayerDataTypes.Entitlements

local MAX_KEY_LENGTH = 64

local EntitlementRules = {}

function EntitlementRules.isKey(value: string): boolean
	return #value >= 1 and #value <= MAX_KEY_LENGTH
end

function EntitlementRules.owns(entitlements: Entitlements, category: string, id: string): boolean
	local ids = entitlements.owned[category]
	return ids ~= nil and ids[id] == true
end

function EntitlementRules.grant(entitlements: Entitlements, category: string, id: string): boolean
	local ids = entitlements.owned[category]
	if ids == nil then
		ids = {}
		entitlements.owned[category] = ids
	end
	if ids[id] then
		return false
	end
	ids[id] = true
	return true
end

function EntitlementRules.revoke(entitlements: Entitlements, category: string, id: string): boolean
	local ids = entitlements.owned[category]
	if ids == nil or not ids[id] then
		return false
	end
	ids[id] = nil
	if next(ids) == nil then
		entitlements.owned[category] = nil
	end
	return true
end

function EntitlementRules.ownedIn(entitlements: Entitlements, category: string): { string }
	local list: { string } = {}
	local ids = entitlements.owned[category]
	if ids ~= nil then
		for id in ids do
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

function EntitlementRules.validate(entitlements: Entitlements): (boolean, string?)
	local owned = entitlements.owned
	if type(owned) ~= "table" then
		return false, "entitlements.owned must be a table"
	end
	for category, ids in owned do
		if type(category) ~= "string" or not EntitlementRules.isKey(category) then
			return false, `bad entitlement category {tostring(category)}`
		end
		if type(ids) ~= "table" then
			return false, `entitlements.owned.{category} must be a table`
		end
		for id, value in ids do
			if type(id) ~= "string" or not EntitlementRules.isKey(id) then
				return false, `bad entitlement id in {category}`
			end
			if value ~= true then
				return false, `entitlements.owned.{category}.{id} must be true`
			end
		end
	end
	return true, nil
end

return EntitlementRules
