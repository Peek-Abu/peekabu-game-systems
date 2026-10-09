--!strict
--[=[
	EntitlementServiceClient: the local player's entitlements, read from the replicated `entitlements`
	slice (StateSyncClientStore.entitlements — React reads the atom with `useAtom`). The server grants;
	the client only reads.

	@class EntitlementServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local EntitlementRules = require(ReplicatedStorage.Shared.Features.Entitlement.Rules.EntitlementRules)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

export type EntitlementServiceClient = {
	dependencies: { string },
	entitlements: () -> PlayerDataTypes.Entitlements,
	owns: (self: EntitlementServiceClient, category: string, id: string) -> boolean,
	ownedIn: (self: EntitlementServiceClient, category: string) -> { string },
}

local EntitlementServiceClient: EntitlementServiceClient = {
	dependencies = { "StateSyncServiceClient" },
	entitlements = StateSyncClientStore.entitlements,

	--[=[
		Whether the local player owns it (false until the first sync).
	]=]
	owns = function(_self, category, id)
		return EntitlementRules.owns(StateSyncClientStore.entitlements(), category, id)
	end,

	ownedIn = function(_self, category)
		return EntitlementRules.ownedIn(StateSyncClientStore.entitlements(), category)
	end,
}

return EntitlementServiceClient
