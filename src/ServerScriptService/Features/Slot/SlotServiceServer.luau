--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Guard = require(ReplicatedStorage.Shared.Core.Guard)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local PlayerDataSliceSystem = require(PlayerDataServer.Systems.PlayerDataSliceSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local CharacterReplicationService = require(ServerScriptService.Features.Replication.ReplicationServiceServer)

local MAX_SLOTS = PlayerDataConstants.MAX_SLOTS

-- The unlockedSlots invariant, enforced by the DATA LAYER on every write (see PlayerDataSliceSystem's
-- `validate`). Registering it here makes it hold for ANY path into the slice — including a raw
-- transaction() op (e.g. a future dev-product grant) that never goes through unlockSlot().
-- Slot 1 is always unlocked: a profile that lost it would have no playable character.
local function validateUnlockedSlots(unlocked: { number }): (boolean, string?)
	local seen: { [number]: boolean } = {}
	local hasSlotOne = false
	for _, slot in unlocked do
		if type(slot) ~= "number" or slot ~= math.floor(slot) then
			return false, `unlockedSlots must contain integers, got {slot}`
		end
		if slot < 1 or slot > MAX_SLOTS then
			return false, `unlockedSlots entry {slot} is out of range (1..{MAX_SLOTS})`
		end
		if seen[slot] then
			return false, `unlockedSlots contains duplicate slot {slot}`
		end
		seen[slot] = true
		if slot == 1 then
			hasSlotOne = true
		end
	end
	if not hasSlotOne then
		return false, "unlockedSlots must always contain slot 1"
	end
	return true
end

-- Registers the "unlockedSlots" ACCOUNT slice: which character slots this player owns is an
-- entitlement — it belongs to the account, not to any one character (see the character-slots design).
-- This registration is also what gives the field an owner at all: the profile template is a bare
-- skeleton, and the { 1 } default lives here rather than being hardcoded there.
local unlockedSlotsSlice = PlayerDataSliceSystem.registerAccount("unlockedSlots", { 1 }, function(account)
	return account.unlockedSlots
end, validateUnlockedSlots)

local log = Logger.new("SlotServiceServer")

--[=[
	Public interface of the service — the SINGLE place method/field types are declared. Annotating the
	table literal below pushes each signature down into the matching body, so the methods need no
	inline annotations and there are zero casts (see CurrencyServiceServer for the same shape).

	This service owns the "which characters does this account own" question, and the switch between
	them.
]=]
export type SlotServiceServer = {
	dependencies: { string },

	init: (self: SlotServiceServer) -> (),
	getActiveSlot: (self: SlotServiceServer, userId: number) -> number?,
	getSlotEpoch: (self: SlotServiceServer, userId: number) -> number?,
	getUnlockedSlots: (self: SlotServiceServer, userId: number) -> { number }?,
	isSlotUnlocked: (self: SlotServiceServer, userId: number, slotIndex: number) -> boolean,
	unlockSlot: (self: SlotServiceServer, userId: number, slotIndex: number) -> boolean,
	unlockedSlotsOp: (
		self: SlotServiceServer,
		userId: number,
		mutator: (unlocked: { number }) -> boolean
	) -> PlayerDataService.TransactionOperation,
	switchSlot: (self: SlotServiceServer, player: Player, slotIndex: number) -> (boolean, string?),
}

local SlotServiceServer: SlotServiceServer = {
	dependencies = { "PlayerDataServiceServer", "ReplicationServiceServer" },

	--[=[
		Initializes the SlotServiceServer.
		@param self SlotServiceServer -- The service instance
	]=]
	init = function(_self)
		log:debug("SlotServiceServer initialized")
	end,

	--[=[
		The slot the player is currently playing.
		@param userId number -- The user ID
		@return number? -- The active slot index, or nil if the profile isn't loaded
	]=]
	getActiveSlot = function(_self, userId)
		Guard.userId(userId)
		return PlayerDataService:getActiveSlot(userId)
	end,

	--[=[
		The generation of the player's current character — bumped by every successful switchSlot below,
		monotonic, never reset (see PlayerDataTypes.SlotState). Exposed here so callers that already
		depend on SlotService don't have to reach into the data layer for it.
		@param userId number -- The user ID
		@return number? -- The current slot epoch, or nil if the profile isn't loaded
	]=]
	getSlotEpoch = function(_self, userId)
		Guard.userId(userId)
		return PlayerDataService:getSlotEpoch(userId)
	end,

	--[=[
		The slots this account owns. Account-wide: an entitlement, not a per-character fact.
		@param userId number -- The user ID
		@return { number }? -- The unlocked slot indices, or nil if the profile isn't loaded
	]=]
	getUnlockedSlots = function(_self, userId)
		Guard.userId(userId)
		return unlockedSlotsSlice.get(userId)
	end,

	--[=[
		True if the player owns this slot. False (not nil, not an error) when the profile isn't loaded,
		so a caller gating on this fails CLOSED — it denies rather than allows.
		@param userId number -- The user ID
		@param slotIndex number -- 1..MAX_SLOTS
		@return boolean -- True if the slot is unlocked
	]=]
	isSlotUnlocked = function(_self, userId, slotIndex)
		Guard.userId(userId)
		Guard.slotIndex(slotIndex, MAX_SLOTS)

		local unlocked = unlockedSlotsSlice.get(userId)
		if not unlocked then
			return false
		end
		return table.find(unlocked, slotIndex) ~= nil
	end,

	--[=[
		Grants a slot to this account. IDEMPOTENT — granting an already-owned slot is a no-op that
		returns false ("no change"), never a duplicate entry. That matters because the eventual caller is
		a Robux receipt, and receipt processing is at-least-once: a double-delivered grant must not
		corrupt the slice.

		This is the GRANT primitive only. What causes a grant (a dev product today, possibly a
		progression unlock later) is deliberately not this service's concern.

		@param userId number -- The user ID
		@param slotIndex number -- 1..MAX_SLOTS
		@return boolean -- True if the slot was NEWLY unlocked; false if already owned or not loaded
	]=]
	unlockSlot = function(_self, userId, slotIndex)
		Guard.userId(userId)
		Guard.slotIndex(slotIndex, MAX_SLOTS)

		local changed = unlockedSlotsSlice.mutate(userId, function(unlocked)
			if table.find(unlocked, slotIndex) then
				return false -- Already owned: no change, and NOT a duplicate insert
			end
			table.insert(unlocked, slotIndex)
			return true
		end)

		if changed then
			log:audit(`userId={userId}`, "SLOT_UNLOCKED", `slot={slotIndex}`)
		end
		return changed
	end,

	--[=[
		Mints a typed TransactionOperation over the unlockedSlots slice, for composing an atomic write
		that grants a slot ALONGSIDE other data changes (the motivating case: a dev-product receipt that
		must debit/credit and unlock in ONE all-or-nothing write, so a half-applied purchase is
		impossible). The mutator's param is typed to the slice; the registered invariant
		(validateUnlockedSlots) still runs on the result, so a raw grant cannot corrupt the slice.
		Pure packaging: nothing runs until transaction() executes the op. Same shape as
		CurrencyService:currencyOp.

		ACCOUNT-scoped, so — unlike a slot-scoped op — it carries NO slot epoch and is never rejected as
		stale: which characters an account owns is slot-independent, so a character switch between the
		mint and the commit cannot invalidate it. See PlayerDataSliceSystem's registerAccount `op`.

		@param userId number -- The user ID the op targets
		@param mutator (unlocked: { number }) -> boolean -- Typed mutator; return false to abort the transaction
		@return PlayerDataService.TransactionOperation
	]=]
	unlockedSlotsOp = function(_self, userId, mutator)
		return unlockedSlotsSlice.op(userId, mutator)
	end,

	--[=[
		Switches the player to another character slot.

		A switch is NOT a persistence event: every slot already lives in the same ProfileStore key, so
		this is zero DataStore calls, no session lock, and no crash window. If the server dies
		mid-switch the player simply wakes up in whichever slot the last save recorded — nothing is
		duplicated or lost.

		EVERY rejection is decided BEFORE the first side effect. The body is respawned only once the
		switch is certain: discovering a refusal after the respawn would leave the player standing in
		the wrong body, or in none.

		The transaction guard refuses a switch while a transaction() is EXECUTING for this userId
		(profilesInTransaction is set for the duration of transaction(), including its yielding
		commit-save — see PlayerDataServiceServer). That is worth having on its own: it fails fast with
		a clear reason instead of letting mutate() discover the locked profile later, mid-switch.

		It does NOT close the mint-and-hold window: PlayerDataSliceSystem.op takes no lock at all, so a caller that
		mints an op and then holds it across a yield (e.g. a trade awaiting confirmation) can still call
		switchSlot in between — isInTransaction only becomes true once transaction() actually starts.
		That window is closed by the EPOCH bumped below instead: a slot-scoped op carries the generation
		it was minted under, and transaction() rejects the whole transaction if it no longer matches, so
		the held op is CANCELLED rather than committed against the abandoned character. The switch is
		therefore allowed to proceed and simply invalidates the in-flight ops. Do not weaken the guard
		above to a warning; it just isn't what closes that particular window.

		@param player Player -- The switching player (their body is respawned)
		@param slotIndex number -- The slot to switch to, 1..MAX_SLOTS
		@return (boolean, string?) -- Success, plus a human-readable reason when refused. NOTE: `true`
			means the switch was committed and mirrored and a respawn was requested, NOT that the new
			body exists yet — the respawn does not yield; the owner rebuilds its rig when the server's
			Spawn reaches it.
	]=]
	switchSlot = function(self, player, slotIndex)
		local userId = player.UserId
		Guard.userId(userId)
		Guard.slotIndex(slotIndex, MAX_SLOTS)

		-- ---- validate: everything that can refuse, refuses HERE, before any side effect ----
		local activeSlot = PlayerDataService:getActiveSlot(userId)
		if not activeSlot then
			return false, "Your data is still loading - try again in a moment"
		end
		if activeSlot == slotIndex then
			return false, "You are already playing that character"
		end
		if not self:isSlotUnlocked(userId, slotIndex) then
			return false, "You do not own that character slot"
		end
		if PlayerDataService:isInTransaction(userId) then
			-- See the header: refuses while transaction() is actually EXECUTING for this userId — fails
			-- fast with a clear reason instead of letting mutate() discover the locked profile later,
			-- mid-switch. The separate mint-and-hold window (PlayerDataSliceSystem.op takes no lock) is closed by the
			-- epoch check inside transaction() instead, not by this guard.
			return false, "Something is still in progress - try again in a moment"
		end

		-- ---- commit ----
		-- `slotState` is a TABLE, which is what makes this writable at all: mutate hands the mutator the
		-- value and expects IN-PLACE mutation, so a bare `activeSlot` number could never be set. It is a
		-- bare ROOT key (core profile state, not a slice), so this mutate replicates NOTHING on its own —
		-- the re-mirror below is mandatory.
		local switched = PlayerDataService:mutate(userId, "slotState", function(slotState: PlayerDataTypes.SlotState)
			slotState.active = slotIndex
			-- Bump the generation in the SAME write that moves the slot: any transaction op minted
			-- against the old character is now stale and will be rejected by transaction(). One atomic
			-- mutate, so `active` and `epoch` can never disagree. Monotonic — never reset, never derived
			-- from slotIndex (switching back must NOT restore an older generation).
			slotState.epoch += 1
			return true
		end)
		if not switched then
			return false, "Could not switch character - try again"
		end

		-- Re-mirror EVERY slice. Every synced slice's reader projects `slots[slotState.active]`, so
		-- re-reading them all IS the switch as far as the client is concerned — this one call is what
		-- swaps the client's view to the new character. getProfile hands back a deep-FROZEN copy, which
		-- is exactly what syncFromProfile needs: it only READS the profile through each slice's reader
		-- and deep-copies the result into the atom, so no live table is required and none is mutated.
		local profile = PlayerDataService:getProfile(userId)
		if profile then
			StateSyncServerStore.syncFromProfile(userId, profile)
		else
			-- Unreachable today: mutate() just succeeded above, which requires a loaded profile. Logged
			-- rather than silently skipped so it can never fail quietly if that ever changes — the
			-- client would be left showing the previous slot's data until the next write re-mirrors it.
			log:error(
				`userId={userId}`,
				`switchSlot: getProfile returned nil after a successful mutate; mirror not refreshed, client may show stale slot data`
			)
		end

		log:audit(`userId={userId}`, "SLOT_SWITCHED", `from={activeSlot} to={slotIndex}`)

		-- Respawn LAST: the profile and the mirror already describe the new character, so the new body
		-- spawns into correct state. Bodies are client-only (character replication): the replication
		-- service bumps the body epoch, picks the spawn, and tells the owner to rebuild its rig. It does not
		-- yield — the same contract LoadCharacter() had, without the engine character LoadCharacter would
		-- spawn over the client-built rig even with CharacterAutoLoads off (spec CP10). A respawn refused
		-- because the previous one was under 250 ms ago is fine: that body is already fresh.
		CharacterReplicationService:respawn(player, "slot switch")
		return true
	end,
}

return SlotServiceServer
