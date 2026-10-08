--!strict
--[=[
	Unit tests for SlotServiceServer.

	Mock strategy: identical to CurrencyServiceServer.spec — patch PlayerDataService's methods inside
	beforeAll/afterAll so this file owns its mock window and doesn't clash with the other specs that
	patch the same table. Patching works because PlayerDataSliceSystem looks PlayerDataService up through the
	table at CALL time.

	unlockedSlots is an ACCOUNT slice, so the reads/writes under test go through _getAccountShell and a
	dotted "account.unlockedSlots" mutate. The fake profile is still whole-profile shaped (slotState /
	account / slots), because getActiveSlot is part of this service's surface too.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local PlayerDataPathUtils = require(PlayerDataServer.Utils.PlayerDataPathUtils)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local SlotService = require(ServerScriptService.Features.Slot.SlotServiceServer)
local CharacterReplicationService = require(ServerScriptService.Features.Replication.ReplicationServiceServer)

local USER_ID = 42

-- Each slot carries DIFFERENT currency, so the re-mirror test can prove the atom now projects the
-- slot the player switched TO (and not the one they left).
local SLOT_JAKU = { 100, 200, 300 }

-- A freshly-created profile: account seeded with the slice's registered template default (see
-- SlotServiceServer's PlayerDataSliceSystem.registerAccount call — only slot 1 is owned), which is the default
-- this spec now asserts, since PlayerDataConstants no longer hardcodes it.
local function makeProfile()
	local slots = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = {
			currency = { jaku = SLOT_JAKU[index] or 0 },
			inventory = { items = {} },
			stats = { totalXp = 0, investments = {} },
			equipment = { slots = {} },
			appearance = { cosmetics = {}, accessories = {}, body = {}, headType = "Uncovered", surfaces = {} },
			bank = { items = {}, currency = {} },
			equippedTitle = {},
		}
	end
	return {
		slotState = { active = 1, epoch = 1 },
		account = {
			unlockedSlots = { 1 },
			itemMint = { nextUid = 1 },
			entitlements = { cosmetics = {} },
			titles = { earned = {} },
		},
		slots = slots,
	}
end

-- The narrow Player surface switchSlot uses: UserId. The respawn itself goes through
-- ReplicationServiceServer:respawn, patched below to count calls per user — every rejection path
-- asserts zero respawns, which proves we never respawn a player we are about to refuse.
local function fakePlayer(userId: number)
	return { UserId = userId }
end

local respawnCalls: { [number]: number } = {}

local function respawns(userId: number): number
	return respawnCalls[userId] or 0
end

return function()
	describe("SlotServiceServer", function()
		local _profiles: { [number]: any } = {}
		local _inTransaction: { [number]: boolean } = {}

		local _origGetActiveSlot
		local _origGetSlotEpoch
		local _origGetAccountShell
		local _origGetProfile
		local _origIsInTransaction
		local _origMutate
		local _origRespawn

		local function setInTransaction(userId: number, value: boolean)
			_inTransaction[userId] = value
		end

		beforeAll(function()
			_origGetActiveSlot = PlayerDataService.getActiveSlot
			_origGetSlotEpoch = PlayerDataService.getSlotEpoch
			_origGetAccountShell = PlayerDataService._getAccountShell
			_origGetProfile = PlayerDataService.getProfile
			_origIsInTransaction = PlayerDataService.isInTransaction
			_origMutate = PlayerDataService.mutate

			-- The re-mirror reads the whole profile through this; production hands back a frozen deep
			-- COPY, and syncFromProfile only ever reads it, so the live fake is an equivalent stand-in.
			PlayerDataService.getProfile = function(_self: any, userId: number): any
				return _profiles[userId]
			end

			PlayerDataService.isInTransaction = function(_self: any, userId: number): boolean
				return _inTransaction[userId] == true
			end

			PlayerDataService.getActiveSlot = function(_self: any, userId: number): number?
				local profile = _profiles[userId]
				return if profile then profile.slotState.active else nil
			end

			PlayerDataService.getSlotEpoch = function(_self: any, userId: number): number?
				local profile = _profiles[userId]
				return if profile then profile.slotState.epoch else nil
			end

			-- Mirrors _getAccountShell's nil contract (unloaded profile / missing slice) and returns the
			-- account directly — the reader projects the slice out of it, same as production.
			PlayerDataService._getAccountShell = function(_self: any, userId: number, slice: string)
				local profile = _profiles[userId]
				if not profile or profile.account[slice] == nil then
					return nil
				end
				return profile.account
			end

			-- Walks the DOTTED path as PlayerDataService.resolvePath does.
			PlayerDataService.mutate = function(
				_self: any,
				userId: number,
				path: string,
				mutator: (data: any) -> boolean?
			): boolean
				local container: any = _profiles[userId]
				if not container then
					return false
				end
				local segments = PlayerDataPathUtils.segments(path)
				for index = 1, #segments - 1 do
					local segment = segments[index]
					container = container[tonumber(segment) or segment]
					if type(container) ~= "table" then
						return false
					end
				end
				local data = container[segments[#segments]]
				if data == nil then
					return false
				end
				local result = mutator(data)
				return result ~= false
			end

			_origRespawn = CharacterReplicationService.respawn
			CharacterReplicationService.respawn = function(_self: any, player: any, _reason: string): boolean
				respawnCalls[player.UserId] = respawns(player.UserId) + 1
				return true
			end
		end)

		afterAll(function()
			PlayerDataService.getActiveSlot = _origGetActiveSlot
			PlayerDataService.getSlotEpoch = _origGetSlotEpoch
			PlayerDataService._getAccountShell = _origGetAccountShell
			PlayerDataService.getProfile = _origGetProfile
			PlayerDataService.isInTransaction = _origIsInTransaction
			PlayerDataService.mutate = _origMutate
			CharacterReplicationService.respawn = _origRespawn
			-- The switch tests mirror into the REAL StateSyncServerStore; drop the entry so no atom keeps a
			-- snapshot for a user that only ever existed inside this spec.
			StateSyncServerStore.remove(USER_ID)
		end)

		beforeEach(function()
			_profiles = {}
			_profiles[USER_ID] = makeProfile()
			_inTransaction = {}
		end)

		-- -------------------------------------------------------------------------
		describe("getActiveSlot", function()
			it("returns the profile's active slot", function()
				expect(SlotService:getActiveSlot(USER_ID)).to.equal(1)
			end)

			it("returns nil when the profile is not loaded", function()
				expect(SlotService:getActiveSlot(999)).to.equal(nil)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("getSlotEpoch", function()
			it("returns the profile's slot epoch", function()
				expect(SlotService:getSlotEpoch(USER_ID)).to.equal(1)
			end)

			it("returns nil when the profile is not loaded", function()
				expect(SlotService:getSlotEpoch(999)).to.equal(nil)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("getUnlockedSlots", function()
			it("starts with only slot 1 unlocked", function()
				local unlocked = SlotService:getUnlockedSlots(USER_ID)
				expect(#unlocked).to.equal(1)
				expect(unlocked[1]).to.equal(1)
			end)

			it("returns nil when the profile is not loaded", function()
				expect(SlotService:getUnlockedSlots(999)).to.equal(nil)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("isSlotUnlocked", function()
			it("is true for slot 1 by default", function()
				expect(SlotService:isSlotUnlocked(USER_ID, 1)).to.equal(true)
			end)

			it("is false for a locked slot", function()
				expect(SlotService:isSlotUnlocked(USER_ID, 2)).to.equal(false)
			end)

			-- Fails CLOSED: a caller gating on this must deny, not allow, when data is missing.
			it("is false for a userId with no profile", function()
				expect(SlotService:isSlotUnlocked(999, 1)).to.equal(false)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("unlockSlot", function()
			it("unlocks a locked slot", function()
				expect(SlotService:unlockSlot(USER_ID, 2)).to.equal(true)
				expect(SlotService:isSlotUnlocked(USER_ID, 2)).to.equal(true)
			end)

			-- The eventual caller is a Robux receipt, and receipt processing is at-least-once: a
			-- double-delivered grant must be a no-op, never a duplicate entry.
			it("is idempotent — unlocking an already-unlocked slot is a no-op, not a duplicate", function()
				expect(SlotService:unlockSlot(USER_ID, 2)).to.equal(true)
				expect(SlotService:unlockSlot(USER_ID, 2)).to.equal(false)

				local unlocked = SlotService:getUnlockedSlots(USER_ID)
				local count = 0
				for _, slot in unlocked do
					if slot == 2 then
						count += 1
					end
				end
				expect(count).to.equal(1)
			end)

			it("rejects an out-of-range slot", function()
				expect(function()
					SlotService:unlockSlot(USER_ID, PlayerDataConstants.MAX_SLOTS + 1)
				end).to.throw()
				expect(function()
					SlotService:unlockSlot(USER_ID, 0)
				end).to.throw()
			end)

			it("returns false when the profile is not loaded", function()
				expect(SlotService:unlockSlot(999, 2)).to.equal(false)
			end)
		end)

		-- -------------------------------------------------------------------------
		describe("switchSlot", function()
			beforeEach(function()
				table.clear(respawnCalls)
			end)

			it("switches to an unlocked slot and respawns the body", function()
				SlotService:unlockSlot(USER_ID, 2)
				local player = fakePlayer(USER_ID)

				local ok, reason = SlotService:switchSlot(player, 2)

				expect(ok).to.equal(true)
				expect(reason).to.never.be.ok()
				expect(SlotService:getActiveSlot(USER_ID)).to.equal(2)
				expect(respawns(player.UserId)).to.equal(1)
			end)

			-- slotState is a bare ROOT key, not a synced slice, so the mutate replicates NOTHING on its
			-- own. Without the explicit re-mirror the client would keep showing the OLD character's
			-- currency until some later write happened to target the new slot.
			it("re-mirrors every slice so the client sees the new character's data", function()
				SlotService:unlockSlot(USER_ID, 2)

				expect(SlotService:switchSlot(fakePlayer(USER_ID), 2)).to.equal(true)

				expect(StateSyncServerStore.snapshot("currency")[USER_ID].jaku).to.equal(SLOT_JAKU[2])
			end)

			-- The epoch is the generation counter that lets transaction() reject an op minted against a
			-- character the player has since left (Task 2). It is bumped in the SAME mutate that moves
			-- `active`, so the two can never disagree — and it is MONOTONIC, not a copy of the slot index.
			it("increments the epoch on a successful switch", function()
				SlotService:unlockSlot(USER_ID, 2)
				local before = SlotService:getSlotEpoch(USER_ID)

				SlotService:switchSlot(fakePlayer(USER_ID), 2)

				expect(SlotService:getSlotEpoch(USER_ID)).to.equal(before + 1)
			end)

			-- Monotonic: switching BACK does not restore the old epoch. An op minted before either
			-- switch must stay stale forever.
			it("keeps climbing across a switch back (never resets)", function()
				SlotService:unlockSlot(USER_ID, 2)
				local before = SlotService:getSlotEpoch(USER_ID)

				SlotService:switchSlot(fakePlayer(USER_ID), 2)
				SlotService:switchSlot(fakePlayer(USER_ID), 1)

				expect(SlotService:getActiveSlot(USER_ID)).to.equal(1)
				expect(SlotService:getSlotEpoch(USER_ID)).to.equal(before + 2)
			end)

			it("does NOT increment the epoch on a refused switch", function()
				local before = SlotService:getSlotEpoch(USER_ID)
				SlotService:switchSlot(fakePlayer(USER_ID), 3) -- locked slot
				expect(SlotService:getSlotEpoch(USER_ID)).to.equal(before)
			end)

			it("REFUSES a locked slot, and changes nothing", function()
				local player = fakePlayer(USER_ID)

				local ok, reason = SlotService:switchSlot(player, 3) -- never unlocked

				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				expect(SlotService:getActiveSlot(USER_ID)).to.equal(1)
				expect(respawns(player.UserId)).to.equal(0) -- did NOT despawn
			end)

			-- The guard is load-bearing: an op minted against the OLD slot and held across a yield would
			-- otherwise commit against the character the player just left, invisibly to the client.
			it("REFUSES while a transaction is in flight, without respawning", function()
				SlotService:unlockSlot(USER_ID, 2)
				local player = fakePlayer(USER_ID)
				setInTransaction(USER_ID, true)

				local ok, reason = SlotService:switchSlot(player, 2)

				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				expect(SlotService:getActiveSlot(USER_ID)).to.equal(1)
				expect(respawns(player.UserId)).to.equal(0)
			end)

			it("REFUSES a switch to the slot already active (no pointless respawn)", function()
				local player = fakePlayer(USER_ID)

				local ok, reason = SlotService:switchSlot(player, 1)

				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				expect(respawns(player.UserId)).to.equal(0)
			end)

			it("REFUSES an out-of-range slot", function()
				expect(function()
					SlotService:switchSlot(fakePlayer(USER_ID), PlayerDataConstants.MAX_SLOTS + 1)
				end).to.throw()
				expect(function()
					SlotService:switchSlot(fakePlayer(USER_ID), 0)
				end).to.throw()
			end)

			it("REFUSES when the profile is not loaded", function()
				local player = fakePlayer(999)

				local ok, reason = SlotService:switchSlot(player, 1)

				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				expect(respawns(player.UserId)).to.equal(0)
			end)
		end)

		-- -------------------------------------------------------------------------
		-- The slice's default now lives with its owner, so it is asserted here rather than against the
		-- PlayerDataConstants skeleton (which no longer hardcodes it).
		describe("slice registration", function()
			it("stamps only slot 1 as unlocked on new profiles", function()
				local unlocked = PlayerDataConstants.PROFILE_TEMPLATE.account.unlockedSlots
				expect(#unlocked).to.equal(1)
				expect(unlocked[1]).to.equal(1)
			end)
		end)

		-- -------------------------------------------------------------------------
		-- The registered validator is what makes the invariant hold for ANY write into the slice —
		-- including a raw transaction() op that never goes through unlockSlot.
		describe("unlockedSlots validator", function()
			local function validator()
				local found = PlayerDataConstants.getValidator(PlayerDataPathUtils.forAccount("unlockedSlots"))
				assert(found, "unlockedSlots must register a data-layer validator")
				return found
			end

			it("accepts a valid set", function()
				expect(validator()({ 1, 3 })).to.equal(true)
			end)

			it("rejects a set without slot 1 (a profile with no playable character)", function()
				expect(validator()({ 2 })).to.equal(false)
			end)

			it("rejects duplicates", function()
				expect(validator()({ 1, 2, 2 })).to.equal(false)
			end)

			it("rejects an out-of-range slot", function()
				expect(validator()({ 1, PlayerDataConstants.MAX_SLOTS + 1 })).to.equal(false)
				expect(validator()({ 1, 0 })).to.equal(false)
			end)

			it("rejects a non-integer slot", function()
				expect(validator()({ 1, 2.5 })).to.equal(false)
			end)
		end)
	end)
end
