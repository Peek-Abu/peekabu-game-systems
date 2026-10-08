--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TitleShared = ReplicatedStorage.Shared.Features.Title
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local TitleRegistry = require(TitleShared.Data.TitleRegistry)
local TitleSliceRules = require(TitleShared.Rules.TitleSliceRules)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local TitleEvents = require(TitleShared.Net.TitleEvents)
local TitleRequestRules = require(TitleShared.Rules.TitleRequestRules)

-- The ACCOUNT-WIDE earned slice: earning a title is about the player, once, usable by every
-- character (titles design spec, Decision 2 — the entitlement model). The validator makes the
-- lenient-vs-hard table a DATA-LAYER guarantee: malformed structure is rejected on every write
-- path, retired ids never freeze a save.
local titlesSlice = PlayerDataSliceSystem.registerAccount("titles", { earned = {} }, function(account)
	return account.titles
end, TitleSliceRules.validateTitles)

-- The SLOT-SCOPED wear slice: different characters wear different titles (Decision 2). Shape only
-- in the validator; "equipped ∈ earned" is cross-slice and therefore SERVICE policy (see
-- TitleSliceRules's class header) — equip pre-checks earned, revoke clears equipped atomically.
local equippedTitleSlice = PlayerDataSliceSystem.registerSlot("equippedTitle", {}, function(slot)
	return slot.equippedTitle
end, TitleSliceRules.validateEquippedTitle)

local log = Logger.new("TitleServiceServer")

local janitor = Janitor.new()

--[=[
	The equip dispatch, shared by the network handler and the service method (named, not inlined,
	so the spec exercises exactly what production runs — the DebuggerServiceServer pattern). The
	wrap applies the rate limit + xpcall isolation; parseEquip is the trust-boundary shape guard.
]=]
local function equipImpl(userId: number, titleId: string): (boolean, string?)
	Guard.userId(userId)
	assert(TitleRegistry.isValidTitleId(titleId), `"{titleId}" is not a registered title`)
	local earned = titlesSlice.get(userId)
	if earned == nil then
		return false, "no profile loaded"
	end
	if earned.earned[titleId] ~= true then
		return false, `"{titleId}" is not earned — it cannot be equipped`
	end
	local current = equippedTitleSlice.get(userId)
	if current ~= nil and current.equipped == titleId then
		return false, `"{titleId}" is already equipped`
	end
	local changed, mutateReason = equippedTitleSlice.mutate(userId, function(state)
		state.equipped = titleId
		return true
	end)
	if not changed then
		-- `earned` above already proved the profile is loaded, with no yield since (Lua is
		-- single-threaded, and nothing here yields) -- so a bare `false` with no validator reason
		-- here is NOT "no profile loaded". It is PlayerDataService refusing the write for a
		-- different cause: locked by a pending transaction, or the session ended in this narrow
		-- window (PlayerDataServiceServer.luau:701-720, mutate's bare-`false` branches). Cmdr
		-- surfaces this text verbatim to an admin, so conflating the two would mislead them into
		-- thinking the profile never loaded at all.
		return false, mutateReason or "write refused (profile locked or session no longer active)"
	end
	return true
end

local onEquipRequest = RequestHandler.wrap({
	name = "TitleEquipRequest",
	rateLimit = { maxRequests = 10, windowSeconds = 10 },
	handler = function(payload: unknown, player: Player)
		local titleId, reason = TitleRequestRules.parseEquip(payload)
		if titleId == nil then
			log:warn(`bad EquipRequest from {player.Name}: {reason or "?"}`)
			return
		end
		-- Registry membership is a REFUSAL here, not the equipImpl assert's job: a well-formed but
		-- unregistered id (e.g. a stale client, or a hostile one) is expected wire traffic, not
		-- programmer error. Checking it before equipImpl keeps the assert reachable only by
		-- in-process callers, matching BankReceiver.luau's item-spec precedent — otherwise every
		-- unregistered id would raise, and RequestHandler's xpcall would log it at ERROR with a
		-- full traceback, up to 10 times per 10s per client.
		if not TitleRegistry.isValidTitleId(titleId) then
			log:debug(`EquipRequest refused for {player.Name} - unknown title "{titleId}"`)
			return
		end
		equipImpl(player.UserId, titleId)
	end,
})

--[=[
	Public interface of the service — the SINGLE place method/field types are declared. One
	annotated literal below; signatures push down into the bodies, zero casts.

	Writes reach the owning client through the reactive path only: a committed mutation mirrors
	into StateSyncServerStore (via StateSyncSliceRegistry's "titles"/"equippedTitle" readers) and charm-sync ships
	the delta. There is no per-write broadcast packet.
]=]
export type TitleServiceServer = {
	dependencies: { string },

	init: (self: TitleServiceServer) -> (),
	stop: (self: TitleServiceServer) -> (),
	award: (self: TitleServiceServer, userId: number, titleId: string) -> (boolean, string?),
	equip: (self: TitleServiceServer, userId: number, titleId: string) -> (boolean, string?),
	revoke: (self: TitleServiceServer, userId: number, titleId: string) -> (boolean, string?),
	getEarned: (self: TitleServiceServer, userId: number) -> PlayerDataTypes.Titles?,
	getEquippedTitle: (self: TitleServiceServer, userId: number) -> string?,
	isEarned: (self: TitleServiceServer, userId: number, titleId: string) -> boolean,
	-- TEST SEAM — the RequestHandler-wrapped equip handler, exposed so specs can drive the
	-- rate-limit + parse + dispatch pipeline without ByteNet. Plain function taking
	-- (payload, player), not a method (DebuggerServiceServer convention).
	_onEquipRequest: (payload: unknown, player: Player) -> any,
	getState: (self: TitleServiceServer) -> { [string]: any },
}

local TitleServiceServer: TitleServiceServer = {
	dependencies = { "PlayerDataServiceServer" },

	--[=[
		Initializes the TitleServiceServer. Both slices were registered at module load, so the
		profile template already owns them before any profile loads. Requiring TitleEvents at
		module load (line 14, before this ever runs) is what creates the per-namespace replicated
		value the client waits on; this just wires the EquipRequest listener.
		@param self TitleServiceServer -- The service instance
	]=]
	init = function(_self)
		janitor:Add(
			TitleEvents.packets.EquipRequest.listen(function(payload: unknown, player: Player?)
				if player then
					onEquipRequest(payload, player)
				end
			end),
			true
		)
		log:debug("TitleServiceServer initialized")
	end,

	--[=[
		Tears down the network listener.
		@param self TitleServiceServer -- The service instance
	]=]
	stop = function(_self)
		janitor:Cleanup()
		log:debug("TitleServiceServer stopped")
	end,

	--[=[
		Awards a registered title to the account. IDEMPOTENT: awarding an already-earned title is a
		reported no-op ("already awarded"), not an error — quest/guild hooks in later phases may
		re-fire. The id must be REGISTERED (asserted): unlike slice validation, which must tolerate
		retired history, awarding a dead id is programmer error (design spec Decision 3).
		@param userId number -- The user ID
		@param titleId string -- A registered title id (TitleRegistry)
		@return boolean, string? -- (ok, reason)
	]=]
	award = function(_self, userId, titleId)
		Guard.userId(userId)
		assert(TitleRegistry.isValidTitleId(titleId), `"{titleId}" is not a registered title`)
		-- Pre-check the profile is loaded so a bare-`false` mutate() outcome below can be told apart
		-- from a genuine load failure (see the comment on that branch).
		if titlesSlice.get(userId) == nil then
			return false, "no profile loaded"
		end
		-- `alreadyEarned` distinguishes a legitimate no-op from a rejection: a no-profile bail and
		-- a validator rejection BOTH surface as `changed == false`, and reporting every falsey
		-- result as "already awarded" would tell an operator their grant succeeded-in-effect when
		-- it had failed (the unlockCosmetic lesson, verbatim).
		local alreadyEarned = false
		local changed, reason = titlesSlice.mutate(userId, function(titles)
			if titles.earned[titleId] == true then
				alreadyEarned = true
				return false -- already earned; idempotent, no write, nothing mirrors
			end
			titles.earned[titleId] = true
			return true
		end)
		if not changed then
			if alreadyEarned then
				return false, "already awarded"
			end
			-- The pre-check above already proved the profile is loaded, with no yield since -- so a
			-- bare `false` with no validator reason here is NOT "no profile loaded". It is
			-- PlayerDataService refusing the write for a different cause: locked by a pending
			-- transaction, or the session ended in this narrow window
			-- (PlayerDataServiceServer.luau:701-720, mutate's bare-`false` branches). Cmdr surfaces
			-- this text verbatim to an admin, so conflating the two would mislead them into thinking
			-- the grant never had a profile to write to.
			return false, reason or "write refused (profile locked or session no longer active)"
		end
		log:audit(`userId={userId}`, "TITLE_AWARDED", titleId)
		return true
	end,

	--[=[
		Equips one of the account's EARNED titles on the active character. Earn-membership is the
		SERVICE's policy gate (a per-slice validator cannot see the account slice — see
		TitleSliceRules's class header): refuse rather than write, so the data-layer validator
		never has to arbitrate what the caller obviously shouldn't have asked for.
		@param userId number -- The user ID
		@param titleId string -- A registered AND earned title id
		@return boolean, string? -- (ok, reason)
	]=]
	equip = function(_self, userId, titleId)
		return equipImpl(userId, titleId)
	end,

	--[=[
		Revokes an earned title. When the active character WEARS the revoked title, the clear is
		part of the SAME PlayerDataService:transaction as the earn removal (design spec Decision 3)
		— one atomic commit, so no observer (including a raw op racing between legs) can ever see a
		worn-but-unearned title. Other characters' worn copies are deliberately untouched: they are
		different slots, and the account no longer earns the id anyway (their wear becomes inert
		history, tolerated by the validators exactly like any retired id).

		Reading `equipped` and committing happen in ONE yield-free call, so the pre-read used to
		decide whether to mint the clear leg cannot go stale inside this function.
		@param userId number -- The user ID
		@param titleId string -- A registered title id
		@return boolean, string? -- (ok, reason)
	]=]
	revoke = function(self, userId, titleId)
		Guard.userId(userId)
		assert(TitleRegistry.isValidTitleId(titleId), `"{titleId}" is not a registered title`)
		if self:getEarned(userId) == nil then
			return false, "no profile loaded"
		end
		local notEarned = false
		-- Ordering consequence: aborting here on `notEarned` also aborts the equip-clear leg below,
		-- so a slot that WEARS a title the account never earned (reachable only via a raw op that
		-- bypassed `equip`'s pre-check, never a shipped path) cannot be repaired by calling revoke
		-- on that id — there is nothing here to "revoke". Fixing such a slot needs a direct
		-- equippedTitle op, not this method.
		local operations: { PlayerDataService.TransactionOperation } = {
			titlesSlice.op(userId, function(titles)
				if titles.earned[titleId] ~= true then
					notEarned = true
					return false -- aborts the whole transaction; nothing is half-revoked
				end
				titles.earned[titleId] = nil
				return true
			end),
		}
		-- Mint the clear leg ONLY when the active character currently wears the revoked id; an
		-- unconditional leg would either abort the transaction (mutator returning false for "no
		-- change") or dirty-mirror an untouched slice (returning true for nothing).
		local worn = equippedTitleSlice.get(userId)
		if worn ~= nil and worn.equipped == titleId then
			table.insert(
				operations,
				equippedTitleSlice.op(userId, function(state)
					state.equipped = nil
					return true
				end)
			)
		end
		local ok, result = PlayerDataService:transaction(operations)
		if not ok then
			if notEarned then
				return false, "not earned"
			end
			return false, result.rejectionReason or "transaction failed"
		end
		log:audit(`userId={userId}`, "TITLE_REVOKED", titleId)
		return true
	end,

	--[=[
		The account's earned-title set.
		@param userId number -- The user ID
		@return PlayerDataTypes.Titles? -- nil if the profile is not loaded
	]=]
	getEarned = function(_self, userId)
		Guard.userId(userId)
		return titlesSlice.get(userId)
	end,

	--[=[
		The title the ACTIVE character currently wears.
		@param userId number -- The user ID
		@return string? -- the title id, or nil if none worn / profile not loaded
	]=]
	getEquippedTitle = function(_self, userId)
		Guard.userId(userId)
		local state = equippedTitleSlice.get(userId)
		if state == nil then
			return nil
		end
		return state.equipped
	end,

	--[=[
		True iff the account has earned `titleId`.
		@param userId number -- The user ID
		@param titleId string -- A REGISTERED title id (asserted — dead ids are programmer error)
		@return boolean
	]=]
	isEarned = function(self, userId, titleId)
		Guard.userId(userId)
		assert(TitleRegistry.isValidTitleId(titleId), `"{titleId}" is not a registered title`)
		local earned = self:getEarned(userId)
		if earned == nil then
			return false
		end
		return earned.earned[titleId] == true
	end,

	--[=[
		Returns the current state of the service for debugging.
		@return { [string]: any } -- Service state
	]=]
	getState = function(_self)
		return {
			note = "Titles data lives in PlayerDataServiceServer profiles (account.titles, "
				.. "slots.*.equippedTitle). Use PlayerDataServiceServer:getState() to inspect.",
		}
	end,

	_onEquipRequest = onEquipRequest,
}

return TitleServiceServer
