--!strict
--[=[
	CosmeticServiceServer: what each player owns and wears (design:
	docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md, step 1).

	- Ownership is the existing account slice `entitlements` (EntitlementServiceServer): CosmeticRegistry registers
	  every item there under its kind. Free defaults are never stored (CosmeticRules.owns).
	- What the player wears is the account slice `loadout`, owned here, validated by CosmeticRules.validateLoadout,
	  replicated to its owner.
	- `equip` and `pick` are refused during a shift (Shift's phase is not "lobby"; owner: no changes in a shift),
	  then checked by CosmeticRules. `grant` / `grantOps` unlock one item (a purchase passes the ops into its own
	  transaction, so paying and unlocking are one write); `grantBundle` unlocks every item of a CosmeticBundleRegistry
	  bundle in one transaction.
	- `changed` fires after every committed change or grant (step 2 rebuilds the character on it).

	@class CosmeticServiceServer
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Cosmetic = ReplicatedStorage.Shared.Features.Cosmetic
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local CosmeticConstants = require(Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(Cosmetic.Data.CosmeticRegistry)
local CosmeticBundleRegistry = require(Cosmetic.Data.CosmeticBundleRegistry)
local CosmeticTypes = require(Cosmetic.Data.CosmeticTypes)
local CosmeticEvents = require(Cosmetic.Net.CosmeticEvents)
local CosmeticOutfitRules = require(Cosmetic.Rules.CosmeticOutfitRules)
local CosmeticDevPickRules = require(Cosmetic.Rules.CosmeticDevPickRules)
local CosmeticRequestRules = require(Cosmetic.Rules.CosmeticRequestRules)
local CosmeticRules = require(Cosmetic.Rules.CosmeticRules)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local EntitlementServiceServer = require(ServerScriptService.Features.Entitlement.EntitlementServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)

type Change = CosmeticTypes.Change
type Look = CosmeticTypes.Look
type Loadout = CosmeticTypes.Loadout

local loadoutSlice = PlayerDataSliceSystem.registerAccount(
	CosmeticConstants.SLICE,
	CosmeticConstants.defaultLoadout(),
	function(account)
		return account.loadout
	end,
	CosmeticRules.validateLoadout
)

local log = Logger.new("CosmeticServiceServer")
local janitor = Janitor.new()
local changed: SignalTyped.Signal<number> = SignalTyped.new()
-- Fired after items reach a player (a grant, a purchase, the first-join pick); the player's client is told so it
-- can play the reveal.
local granted: SignalTyped.Signal<CosmeticTypes.Granted> = SignalTyped.new()
-- Fired after an equip is written, with the player's userId and the change (the New Look badge reads skins).
local equipped: SignalTyped.Signal<number, Change> = SignalTyped.new()

local function announce(userId: number, ids: { string }, source: CosmeticTypes.GrantSource)
	granted:Fire({ userId = userId, ids = table.clone(ids), source = source })
end

-- The player's `owns`, over a snapshot of their entitlements (nil when the profile is not loaded).
local function ownsFor(userId: number): ((id: string) -> boolean)?
	local entitlements = EntitlementServiceServer:getEntitlements(userId)
	if entitlements == nil then
		return nil
	end
	return function(id: string): boolean
		return CosmeticRules.owns(entitlements, id)
	end
end

local function isLocked(): boolean
	return ShiftServiceServer:getShift().phase ~= "lobby"
end

-- The item alone (owner, 2026-11-13: an item never brings others; a bundle is bought or granted as a bundle).
local function grantOps(userId: number, id: string): { PlayerDataService.TransactionOperation }
	local item = CosmeticRegistry.get(id)
	assert(item ~= nil and item.kind ~= "sticker", `{id} is not a grantable cosmetic`)
	if item.source == "default" then
		return {}
	end
	return { EntitlementServiceServer:grantOp(userId, item.kind, id) }
end

local function equipImpl(userId: number, change: Change): (boolean, string?)
	Guard.userId(userId)
	if isLocked() then
		return false, "locked during a shift"
	end
	local loadout = loadoutSlice.get(userId)
	local owns = ownsFor(userId)
	if loadout == nil or owns == nil then
		return false, "no profile loaded"
	end
	local allowed, reason = CosmeticRules.checkEquip(loadout, change, owns)
	if not allowed then
		return false, reason
	end
	local written, writeReason = loadoutSlice.mutate(userId, function(state)
		return CosmeticRules.applyEquip(state, change, owns)
	end)
	if not written then
		return false, writeReason or "write refused (profile locked or session no longer active)"
	end
	changed:Fire(userId)
	equipped:Fire(userId, change)
	return true, nil
end

local function pickImpl(userId: number, employee: string): (boolean, string?)
	Guard.userId(userId)
	if isLocked() then
		return false, "locked during a shift"
	end
	local loadout = loadoutSlice.get(userId)
	local owns = ownsFor(userId)
	if loadout == nil or owns == nil then
		return false, "no profile loaded"
	end
	if loadout.picked then
		return false, "already picked"
	end
	local item = CosmeticRegistry.get(employee)
	if item == nil or item.kind ~= "employee" then
		return false, "unknown item"
	end
	if not owns(employee) then
		return false, "not owned"
	end
	local written, writeReason = loadoutSlice.mutate(userId, function(state)
		state.current = employee
		state.picked = true
		return true
	end)
	if not written then
		return false, writeReason or "write refused (profile locked or session no longer active)"
	end
	changed:Fire(userId)
	announce(userId, { employee }, "pick")
	return true, nil
end

-- Marks owned items seen (clears New!). Allowed in a shift too: it changes nothing anyone wears, so `changed` is
-- not fired.
local function seenImpl(userId: number, ids: { string }): (boolean, string?)
	Guard.userId(userId)
	local loadout = loadoutSlice.get(userId)
	local owns = ownsFor(userId)
	if loadout == nil or owns == nil then
		return false, "no profile loaded"
	end
	local fresh = CosmeticRules.unseen(loadout, ids, owns)
	if #fresh == 0 then
		return false, "nothing new"
	end
	local written, writeReason = loadoutSlice.mutate(userId, function(state)
		for _, id in fresh do
			state.seen[id] = true
		end
		return true
	end)
	if not written then
		return false, writeReason or "write refused (profile locked or session no longer active)"
	end
	return true, nil
end

local onEquipRequest = RequestHandler.wrap({
	name = "CosmeticEquipRequest",
	rateLimit = { maxRequests = 10, windowSeconds = 10 },
	handler = function(payload: unknown, player: Player)
		local change, reason = CosmeticRequestRules.parseEquip(payload)
		if change == nil then
			log:warn(`bad EquipRequest from {player.Name}: {reason or "?"}`)
			return
		end
		local ok, refusal = equipImpl(player.UserId, change)
		if not ok then
			log:debug(`EquipRequest refused for {player.Name}: {refusal or "?"}`)
		end
	end,
})

local onPickRequest = RequestHandler.wrap({
	name = "CosmeticPickRequest",
	rateLimit = { maxRequests = 5, windowSeconds = 10 },
	handler = function(payload: unknown, player: Player)
		local employee, reason = CosmeticRequestRules.parsePick(payload)
		if employee == nil then
			log:warn(`bad PickRequest from {player.Name}: {reason or "?"}`)
			return
		end
		local ok, refusal = pickImpl(player.UserId, employee)
		if not ok then
			log:debug(`PickRequest refused for {player.Name}: {refusal or "?"}`)
		end
	end,
})

local onSeenRequest = RequestHandler.wrap({
	name = "CosmeticSeenRequest",
	rateLimit = { maxRequests = 20, windowSeconds = 10 },
	handler = function(payload: unknown, player: Player)
		local ids, reason = CosmeticRequestRules.parseSeen(payload)
		if ids == nil then
			log:warn(`bad SeenRequest from {player.Name}: {reason or "?"}`)
			return
		end
		seenImpl(player.UserId, ids)
	end,
})

export type CosmeticServiceServer = {
	dependencies: { string },
	changed: SignalTyped.Signal<number>,
	granted: SignalTyped.Signal<CosmeticTypes.Granted>,
	equipped: SignalTyped.Signal<number, Change>,
	announce: (self: CosmeticServiceServer, userId: number, ids: { string }, source: CosmeticTypes.GrantSource) -> (),

	init: (self: CosmeticServiceServer) -> (),
	stop: (self: CosmeticServiceServer) -> (),
	getLoadout: (self: CosmeticServiceServer, userId: number) -> Loadout?,
	owns: (self: CosmeticServiceServer, userId: number, id: string) -> boolean,
	currentEmployee: (self: CosmeticServiceServer, userId: number) -> string,
	lookOf: (self: CosmeticServiceServer, userId: number, employee: string?) -> Look?,
	outfitOf: (self: CosmeticServiceServer, userId: number) -> CosmeticTypes.Outfit?,
	isLocked: (self: CosmeticServiceServer) -> boolean,
	equip: (self: CosmeticServiceServer, userId: number, change: Change) -> (boolean, string?),
	pick: (self: CosmeticServiceServer, userId: number, employee: string) -> (boolean, string?),
	markSeen: (self: CosmeticServiceServer, userId: number, ids: { string }) -> (boolean, string?),
	grant: (self: CosmeticServiceServer, userId: number, id: string) -> (boolean, string?),
	grantBundle: (self: CosmeticServiceServer, userId: number, bundleId: string) -> (boolean, string?),
	grantOps: (self: CosmeticServiceServer, userId: number, id: string) -> { PlayerDataService.TransactionOperation },
	getState: (self: CosmeticServiceServer) -> { [string]: any },
	-- TEST SEAMS: the RequestHandler-wrapped handlers (payload, player), as TitleServiceServer exposes its own.
	_onEquipRequest: (payload: unknown, player: Player) -> any,
	_onPickRequest: (payload: unknown, player: Player) -> any,
	_onSeenRequest: (payload: unknown, player: Player) -> any,
}

local CosmeticServiceServer: CosmeticServiceServer = {
	dependencies = { "PlayerDataServiceServer", "EntitlementServiceServer", "ShiftServiceServer" },
	changed = changed,
	granted = granted,
	equipped = equipped,

	init = function(_self)
		-- Every grant is told to its player's client (the reveal); a player who left is skipped.
		janitor:Add(
			granted:Connect(function(event: CosmeticTypes.Granted)
				local player = Players:GetPlayerByUserId(event.userId)
				if player ~= nil then
					CosmeticEvents.packets.Granted.sendTo({ ids = event.ids, source = event.source }, player)
				end
			end),
			"Disconnect"
		)
		janitor:Add(
			CosmeticEvents.packets.EquipRequest.listen(function(payload: unknown, player: Player?)
				if player then
					onEquipRequest(payload, player)
				end
			end),
			true
		)
		janitor:Add(
			CosmeticEvents.packets.PickRequest.listen(function(payload: unknown, player: Player?)
				if player then
					onPickRequest(payload, player)
				end
			end),
			true
		)
		janitor:Add(
			CosmeticEvents.packets.SeenRequest.listen(function(payload: unknown, player: Player?)
				if player then
					onSeenRequest(payload, player)
				end
			end),
			true
		)
		-- Studio only, opted in (CosmeticDevPickRules): pick for a player who has not picked yet, through the real pick
		-- path (it still refuses an employee they do not own).
		janitor:Add(
			PlayerDataService.profileLoaded:Connect(function(userId: number)
				local employee = CosmeticDevPickRules.employee(
					RunService:IsStudio(),
					workspace:GetAttribute(CosmeticConstants.DEV_PICK_ATTRIBUTE)
				)
				if employee ~= nil then
					local ok, refusal = pickImpl(userId, employee)
					log:info(`dev auto-pick {employee} for {userId}: {if ok then "picked" else refusal or "?"}`)
				end
			end),
			"Disconnect"
		)
	end,

	stop = function(_self)
		janitor:Cleanup()
	end,

	-- The saved loadout (a frozen snapshot), nil when the profile is not loaded.
	getLoadout = function(_self, userId)
		return loadoutSlice.get(userId)
	end,

	owns = function(_self, userId, id)
		local owns = ownsFor(userId)
		return owns ~= nil and owns(id)
	end,

	-- The employee the player plays as (the default until the profile loads or when the saved one is not owned).
	currentEmployee = function(_self, userId)
		local loadout = loadoutSlice.get(userId)
		local owns = ownsFor(userId)
		if loadout == nil or owns == nil then
			return CosmeticConstants.DEFAULT_EMPLOYEE
		end
		return CosmeticRules.currentEmployee(loadout, owns)
	end,

	--[=[
		The look `employee` (default: the current one) wears, every fallback applied; nil when the profile is not
		loaded or the employee is unknown.
	]=]
	lookOf = function(self, userId, employee)
		local loadout = loadoutSlice.get(userId)
		local owns = ownsFor(userId)
		if loadout == nil or owns == nil then
			return nil
		end
		local who = employee or self:currentEmployee(userId)
		local item = CosmeticRegistry.get(who)
		if item == nil or item.kind ~= "employee" then
			return nil
		end
		return CosmeticRules.lookFor(loadout, who, owns)
	end,

	-- Everything the player wears (CosmeticOutfitRules.current); nil when the profile is not loaded.
	outfitOf = function(_self, userId)
		local loadout = loadoutSlice.get(userId)
		local owns = ownsFor(userId)
		if loadout == nil or owns == nil then
			return nil
		end
		return CosmeticOutfitRules.current(loadout, owns)
	end,

	isLocked = function(_self)
		return isLocked()
	end,

	equip = function(_self, userId, change)
		return equipImpl(userId, change)
	end,

	pick = function(_self, userId, employee)
		return pickImpl(userId, employee)
	end,

	-- Marks owned items seen (the New! flag); false "nothing new" when none of them needed it.
	markSeen = function(_self, userId, ids)
		return seenImpl(userId, ids)
	end,

	--[=[
		Unlocks a registered item, alone. False "already owned" when the player has it. Throws for an unknown id or a
		sticker (programmer error: stickers come with their pack).
	]=]
	grant = function(_self, userId, id)
		Guard.userId(userId)
		local ops = grantOps(userId, id)
		local owns = ownsFor(userId)
		if owns == nil then
			return false, "no profile loaded"
		end
		if owns(id) then
			return false, "already owned"
		end
		local ok, result = PlayerDataService:transaction(ops)
		if not ok then
			return false, result.rejectionReason or "transaction failed"
		end
		log:audit(`userId={userId}`, "COSMETIC_GRANTED", id)
		changed:Fire(userId)
		announce(userId, { id }, "grant")
		return true, nil
	end,

	--[=[
		Unlocks every item of a bundle in one transaction (the ones already owned stay owned). False "unknown bundle"
		for an id CosmeticBundleRegistry does not have, "already owned" when the player has every item.
	]=]
	grantBundle = function(_self, userId, bundleId)
		Guard.userId(userId)
		local bundle = CosmeticBundleRegistry.get(bundleId)
		if bundle == nil then
			return false, "unknown bundle"
		end
		local owns = ownsFor(userId)
		if owns == nil then
			return false, "no profile loaded"
		end
		local ops: { PlayerDataService.TransactionOperation } = {}
		for _, id in bundle.items do
			if not owns(id) then
				for _, op in grantOps(userId, id) do
					table.insert(ops, op)
				end
			end
		end
		if #ops == 0 then
			return false, "already owned"
		end
		local ok, result = PlayerDataService:transaction(ops)
		if not ok then
			return false, result.rejectionReason or "transaction failed"
		end
		log:audit(`userId={userId}`, "COSMETIC_BUNDLE_GRANTED", bundleId)
		changed:Fire(userId)
		announce(userId, bundle.items, "grant")
		return true, nil
	end,

	-- Tells the player's client they got these (for a grant committed elsewhere, like a Shop purchase).
	announce = function(_self, userId, ids, source)
		Guard.userId(userId)
		announce(userId, ids, source)
	end,

	grantOps = function(_self, userId, id)
		Guard.userId(userId)
		return grantOps(userId, id)
	end,

	getState = function(_self)
		return { items = #CosmeticRegistry.all(), locked = isLocked() }
	end,

	_onEquipRequest = onEquipRequest,
	_onPickRequest = onPickRequest,
	_onSeenRequest = onSeenRequest,
}

return CosmeticServiceServer
