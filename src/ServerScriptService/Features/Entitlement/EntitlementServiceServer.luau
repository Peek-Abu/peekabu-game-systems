--!strict
--[=[
	EntitlementServiceServer: the account-wide "you own this" slice (design:
	docs/superpowers/specs/2026-10-09-entitlement-design.md). Registered as an ACCOUNT slice with
	EntitlementRules.validate as its data-layer invariant, replicated to the owner as `entitlements`.

	`grantOp` puts a grant inside a transaction — a Marketplace product handler returns it so the purchase
	and the unlock are one atomic, exactly-once write.

	@class EntitlementServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EntitlementShared = ReplicatedStorage.Shared.Features.Entitlement
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local EntitlementRegistry = require(EntitlementShared.Data.EntitlementRegistry)
local EntitlementRules = require(EntitlementShared.Rules.EntitlementRules)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)

local entitlementsSlice = PlayerDataSliceSystem.registerAccount("entitlements", {
	owned = {},
}, function(account)
	return account.entitlements
end, EntitlementRules.validate)

local granted: SignalTyped.Signal<number, string, string> = SignalTyped.new()

local function assertRegistered(category: string, id: string)
	assert(EntitlementRegistry.has(category, id), `entitlement {category}/{id} is not registered`)
end

export type EntitlementServiceServer = {
	dependencies: { string },
	granted: SignalTyped.Signal<number, string, string>,

	getEntitlements: (self: EntitlementServiceServer, userId: number) -> PlayerDataTypes.Entitlements?,
	owns: (self: EntitlementServiceServer, userId: number, category: string, id: string) -> boolean,
	ownedIn: (self: EntitlementServiceServer, userId: number, category: string) -> { string },
	grant: (self: EntitlementServiceServer, userId: number, category: string, id: string) -> (boolean, string?),
	revoke: (self: EntitlementServiceServer, userId: number, category: string, id: string) -> (boolean, string?),
	grantOp: (
		self: EntitlementServiceServer,
		userId: number,
		category: string,
		id: string
	) -> PlayerDataService.TransactionOperation,
	getState: (self: EntitlementServiceServer) -> { [string]: any },
}

local EntitlementServiceServer: EntitlementServiceServer = {
	dependencies = { "PlayerDataServiceServer" },
	granted = granted,

	--[=[
		The player's whole entitlements slice (a frozen snapshot), or nil when the profile is not loaded.
	]=]
	getEntitlements = function(_self, userId)
		return entitlementsSlice.get(userId)
	end,

	owns = function(_self, userId, category, id)
		local entitlements = entitlementsSlice.get(userId)
		return entitlements ~= nil and EntitlementRules.owns(entitlements, category, id)
	end,

	ownedIn = function(_self, userId, category)
		local entitlements = entitlementsSlice.get(userId)
		return if entitlements ~= nil then EntitlementRules.ownedIn(entitlements, category) else {}
	end,

	--[=[
		Grants a registered entitlement. False with a reason when it is already owned or the profile is
		not loaded. Throws for an unregistered id (programmer error). Fires `granted` on success.
	]=]
	grant = function(_self, userId, category, id)
		Guard.userId(userId)
		assertRegistered(category, id)
		if entitlementsSlice.get(userId) == nil then
			return false, "profile not loaded"
		end
		local changed, reason = entitlementsSlice.mutate(userId, function(entitlements)
			return EntitlementRules.grant(entitlements, category, id)
		end)
		if changed then
			granted:Fire(userId, category, id)
			return true, nil
		end
		return false, reason or "already owned"
	end,

	--[=[
		Removes an entitlement (registered or retired). False when it was not owned.
	]=]
	revoke = function(_self, userId, category, id)
		Guard.userId(userId)
		if entitlementsSlice.get(userId) == nil then
			return false, "profile not loaded"
		end
		local changed, reason = entitlementsSlice.mutate(userId, function(entitlements)
			return EntitlementRules.revoke(entitlements, category, id)
		end)
		if changed then
			return true, nil
		end
		return false, reason or "not owned"
	end,

	--[=[
		A transaction op granting a registered entitlement. Succeeds when it is already owned (so a
		repeated purchase never aborts its transaction). `granted` does not fire for ops: the caller knows
		when its transaction committed.
	]=]
	grantOp = function(_self, userId, category, id)
		assertRegistered(category, id)
		return entitlementsSlice.op(userId, function(entitlements)
			EntitlementRules.grant(entitlements, category, id)
			return true
		end)
	end,

	getState = function(_self)
		return { categories = EntitlementRegistry.categories() }
	end,
}

return EntitlementServiceServer
