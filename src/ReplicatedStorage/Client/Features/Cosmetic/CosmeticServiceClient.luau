--!strict
--[=[
	CosmeticServiceClient: the local player's cosmetics, read off StateSyncClientStore.loadout and .entitlements
	(charm-sync keeps them current), the reveals the server announces (into CosmeticRevealStore), plus the requests: equip a change, the first-join pick, and marking items seen. Requests are
	fire-and-forget; the server is authoritative and the atoms are the truth of what happened. Reactive UI reads the
	atoms directly (useAtom); these are point-in-time accessors for everything else.

	@class CosmeticServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetic = ReplicatedStorage.Shared.Features.Cosmetic
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local CosmeticRevealStore = require(ReplicatedStorage.Client.Features.Cosmetic.State.CosmeticRevealStore)
local CosmeticConstants = require(Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(Cosmetic.Data.CosmeticTypes)
local CosmeticEvents = require(Cosmetic.Net.CosmeticEvents)
local CosmeticDevPickRules = require(Cosmetic.Rules.CosmeticDevPickRules)
local CosmeticRequestRules = require(Cosmetic.Rules.CosmeticRequestRules)
local CosmeticRules = require(Cosmetic.Rules.CosmeticRules)

type Change = CosmeticTypes.Change
type Look = CosmeticTypes.Look
type Loadout = CosmeticTypes.Loadout

local function owns(id: string): boolean
	return CosmeticRules.owns(StateSyncClientStore.entitlements(), id)
end

export type CosmeticServiceClient = {
	dependencies: { string },
	init: (self: CosmeticServiceClient) -> (),

	getLoadout: (self: CosmeticServiceClient) -> Loadout,
	owns: (self: CosmeticServiceClient, id: string) -> boolean,
	currentEmployee: (self: CosmeticServiceClient) -> string,
	lookOf: (self: CosmeticServiceClient, employee: string?) -> Look?,
	canEquip: (self: CosmeticServiceClient, change: Change) -> (boolean, string?),
	requestEquip: (self: CosmeticServiceClient, change: Change) -> (),
	requestPick: (self: CosmeticServiceClient, employee: string) -> (),
	markSeen: (self: CosmeticServiceClient, ids: { string }) -> (),
}

local CosmeticServiceClient: CosmeticServiceClient = {
	dependencies = {},
	-- Every grant the server announces is queued for the reveal scene.
	init = function(_self)
		CosmeticEvents.packets.Granted.listen(function(data: { ids: { string }, source: string })
			-- Studio's dev auto-pick (CosmeticDevPickRules) skips its own "You're hired!" reveal.
			local devAttribute = workspace:GetAttribute(CosmeticConstants.DEV_PICK_ATTRIBUTE)
			if CosmeticDevPickRules.skipsReveal(RunService:IsStudio(), devAttribute, data.source) then
				return
			end
			CosmeticRevealStore.push({ ids = data.ids, source = data.source })
		end)
	end,

	getLoadout = function(_self)
		return StateSyncClientStore.loadout()
	end,

	owns = function(_self, id)
		return owns(id)
	end,

	currentEmployee = function(_self)
		return CosmeticRules.currentEmployee(StateSyncClientStore.loadout(), owns)
	end,

	-- The look `employee` (default: the current one) wears, every fallback applied; nil for an unknown employee.
	lookOf = function(self, employee)
		local who = employee or self:currentEmployee()
		local item = CosmeticRegistry.get(who)
		if item == nil or item.kind ~= "employee" then
			return nil
		end
		return CosmeticRules.lookFor(StateSyncClientStore.loadout(), who, owns)
	end,

	-- Whether the server would accept this change now (ownership and fit; the shift lock is the server's call).
	canEquip = function(_self, change)
		return CosmeticRules.checkEquip(StateSyncClientStore.loadout(), change, owns)
	end,

	requestEquip = function(self, change)
		if not self:canEquip(change) then
			return
		end
		CosmeticEvents.packets.EquipRequest.send(CosmeticRequestRules.buildEquip(change))
	end,

	-- Tells the server the player has looked at these items (clears New!); sends only the ones that need it.
	markSeen = function(_self, ids)
		local fresh = CosmeticRules.unseen(StateSyncClientStore.loadout(), ids, owns)
		if #fresh == 0 then
			return
		end
		while #fresh > CosmeticConstants.MAX_SEEN do
			table.remove(fresh)
		end
		CosmeticEvents.packets.SeenRequest.send(CosmeticRequestRules.buildSeen(fresh))
	end,
	requestPick = function(_self, employee)
		if StateSyncClientStore.loadout().picked or not owns(employee) then
			return
		end
		CosmeticEvents.packets.PickRequest.send(CosmeticRequestRules.buildPick(employee))
	end,
}

return CosmeticServiceClient
