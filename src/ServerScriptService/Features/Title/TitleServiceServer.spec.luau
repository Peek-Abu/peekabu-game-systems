--[[
	Unit tests for TitleServiceServer. Same strategy as the Inventory spec:
	seed REAL fake profiles via `_setProfileForTesting` and drive the REAL mutate()/validator
	machinery, so the slice invariants and scopes are exercised rather than mocked.

	The network listener wired in init() is NOT driven here — it needs a live ByteNet transport.
	The wrapped handler is exposed as `_onEquipRequest` (the DebuggerServiceServer precedent) and
	exercised directly in the equip-request tests below.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local TitlesService = require(ServerScriptService.Features.Title.TitleServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local sift = require(ReplicatedStorage.Packages.sift)

local function fakeSignal()
	local handlers: { [(...any) -> ()]: boolean } = {}
	return {
		Connect = function(_self, fn: (...any) -> ())
			handlers[fn] = true
			return {
				Disconnect = function()
					handlers[fn] = nil
				end,
			}
		end,
		Fire = function(_self, ...)
			local snapshot = {}
			for fn in handlers do
				table.insert(snapshot, fn)
			end
			for _, fn in snapshot do
				fn(...)
			end
		end,
	}
end

local function makeFakeProfile(data: any)
	return {
		Data = data,
		LastSavedData = sift.Dictionary.copyDeep(data),
		OnSave = fakeSignal(),
		OnAfterSave = fakeSignal(),
		IsActive = function()
			return true
		end,
		Save = function() end,
	}
end

local function makeProfileData(): PlayerDataTypes.PlayerProfile
	local slots: { PlayerDataTypes.PlayerSlot } = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = {
			currency = {},
			inventory = { items = {} },
			equippedTitle = {},
		}
	end
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			itemMint = { nextUid = 1 },
			premium = { balance = 0 },
			receipts = { ids = {} },
			entitlements = { owned = {} },
			settings = { values = {} },
			dailyReward = { lastDay = 0, streak = 0 },
			titles = { earned = {} },
		},
		slots = slots,
	}
end

return function()
	-- Multi-slot behaviour is dormant while MAX_SLOTS = 1; these re-enable when a game raises it.
	local itMultiSlot = if PlayerDataConstants.MAX_SLOTS >= 2 then it else itSKIP

	describe("TitleServiceServer", function()
		local profiles: { [number]: any } = {}

		local function seed(userId: number)
			local profile = makeFakeProfile(makeProfileData())
			profiles[userId] = profile
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile
		end

		afterEach(function()
			for userId in profiles do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
			end
			profiles = {}
		end)

		describe("slice defaults and reads", function()
			it("reads an empty earned set and no equipped title from a fresh profile", function()
				seed(1)
				local earned = TitlesService:getEarned(1)
				expect(earned).to.be.ok()
				local count = 0
				for _ in earned.earned do
					count += 1
				end
				expect(count).to.equal(0)
				expect(TitlesService:getEquippedTitle(1)).to.equal(nil)
				expect(TitlesService:isEarned(1, "veteran")).to.equal(false)
			end)

			it("reports unloaded profiles as nil reads", function()
				expect(TitlesService:getEarned(999)).to.equal(nil)
				expect(TitlesService:getEquippedTitle(999)).to.equal(nil)
				expect(TitlesService:isEarned(999, "veteran")).to.equal(false)
			end)
		end)

		describe("scoping", function()
			itMultiSlot("keeps earned ACCOUNT-wide while equipped stays PER-SLOT", function()
				local profile = seed(1)
				profile.Data.account.titles.earned.veteran = true
				profile.Data.slots[1].equippedTitle.equipped = "veteran"

				profile.Data.slotState.active = 2

				-- The earn follows the player across characters...
				expect(TitlesService:isEarned(1, "veteran")).to.equal(true)
				-- ...but slot 2 wears nothing.
				expect(TitlesService:getEquippedTitle(1)).to.equal(nil)

				profile.Data.slotState.active = 1
				expect(TitlesService:getEquippedTitle(1)).to.equal("veteran")
			end)
		end)

		describe("award", function()
			it("awards a registered title and persists it", function()
				seed(1)
				local ok = TitlesService:award(1, "veteran")
				expect(ok).to.equal(true)
				expect(TitlesService:isEarned(1, "veteran")).to.equal(true)
			end)

			it("is idempotent: a second award reports no change", function()
				seed(1)
				expect(TitlesService:award(1, "veteran")).to.equal(true)
				local ok, reason = TitlesService:award(1, "veteran")
				expect(ok).to.equal(false)
				expect(reason).to.equal("already awarded")
				expect(TitlesService:isEarned(1, "veteran")).to.equal(true)
			end)

			it("throws for an unregistered id (awarding a dead id is programmer error)", function()
				seed(1)
				expect(function()
					TitlesService:award(1, "deleted-long-ago")
				end).to.throw()
			end)

			it("reports a LOAD failure for an unloaded profile", function()
				local ok, reason = TitlesService:award(999, "veteran")
				expect(ok).to.equal(false)
				expect(string.find(reason, "profile") ~= nil).to.equal(true)
			end)

			it("does NOT report 'no profile loaded' when the profile IS loaded but the write is refused", function()
				-- A loaded-but-inactive session (e.g. the player just disconnected) hits
				-- PlayerDataService:mutate's bare-`false` IsActive branch, not its "profile not
				-- loaded" branch. Reporting the two identically would tell an admin the grant never
				-- reached a profile at all, which is false — the profile IS there, the write was
				-- refused.
				local profile = seed(1)
				profile.IsActive = function()
					return false
				end
				local ok, reason = TitlesService:award(1, "veteran")
				expect(ok).to.equal(false)
				expect(reason).to.never.equal("no profile loaded")
				expect(TitlesService:isEarned(1, "veteran")).to.equal(false)
			end)
		end)

		describe("equip", function()
			it("refuses a title the account has not earned, and writes nothing", function()
				seed(1)
				local ok, reason = TitlesService:equip(1, "veteran")
				expect(ok).to.equal(false)
				expect(string.find(reason, "not earned") ~= nil).to.equal(true)
				expect(TitlesService:getEquippedTitle(1)).to.equal(nil)
			end)

			it("equips an earned title on the active character", function()
				seed(1)
				TitlesService:award(1, "veteran")
				expect(TitlesService:equip(1, "veteran")).to.equal(true)
				expect(TitlesService:getEquippedTitle(1)).to.equal("veteran")
			end)

			it("refuses a repeat equip of the same title", function()
				seed(1)
				TitlesService:award(1, "veteran")
				TitlesService:equip(1, "veteran")
				local ok, reason = TitlesService:equip(1, "veteran")
				expect(ok).to.equal(false)
				expect(string.find(reason, "already equipped") ~= nil).to.equal(true)
			end)

			itMultiSlot("lets a second character wear a different earned title", function()
				local profile = seed(1)
				TitlesService:award(1, "veteran")
				TitlesService:award(1, "champion")
				expect(TitlesService:equip(1, "veteran")).to.equal(true)

				profile.Data.slotState.active = 2
				expect(TitlesService:equip(1, "champion")).to.equal(true)
				expect(TitlesService:getEquippedTitle(1)).to.equal("champion")

				profile.Data.slotState.active = 1
				expect(TitlesService:getEquippedTitle(1)).to.equal("veteran")
			end)

			it("is backed by the DATA LAYER: a raw mutate writing a malformed equipped value rolls back", function()
				seed(1)
				TitlesService:award(1, "veteran")
				-- Bypass the service entirely: the invariant must hold for ANY path into the slice,
				-- including this one (the whole point of registering validateEquippedTitle).
				local ok, reason = PlayerDataService:mutate(1, "slots.1.equippedTitle", function(state)
					state.equipped = 7
					return true
				end)
				expect(ok).to.equal(false)
				expect(reason).to.be.ok()
				expect(TitlesService:getEquippedTitle(1)).to.equal(nil)
			end)

			it("is backed by the DATA LAYER for the earned slice too", function()
				seed(1)
				local ok = PlayerDataService:mutate(1, "account.titles", function(titles)
					titles.earned.veteran = "yes"
					return true
				end)
				expect(ok).to.equal(false)
				expect(TitlesService:getEarned(1).earned.veteran).to.equal(nil)
			end)

			it("throws for an unregistered id", function()
				seed(1)
				expect(function()
					TitlesService:equip(1, "deleted-long-ago")
				end).to.throw()
			end)

			it("does NOT report 'no profile loaded' when the profile IS loaded but the write is refused", function()
				local profile = seed(1)
				TitlesService:award(1, "veteran")
				profile.IsActive = function()
					return false
				end
				local ok, reason = TitlesService:equip(1, "veteran")
				expect(ok).to.equal(false)
				expect(reason).to.never.equal("no profile loaded")
				expect(TitlesService:getEquippedTitle(1)).to.equal(nil)
			end)
		end)

		describe("revoke", function()
			it("removes an earned title from the account", function()
				seed(1)
				TitlesService:award(1, "veteran")
				expect(TitlesService:revoke(1, "veteran")).to.equal(true)
				expect(TitlesService:isEarned(1, "veteran")).to.equal(false)
			end)

			it("ATOMICALLY clears the worn title when revoking it", function()
				seed(1)
				TitlesService:award(1, "veteran")
				TitlesService:equip(1, "veteran")
				expect(TitlesService:revoke(1, "veteran")).to.equal(true)
				-- Both legs committed together: nothing worn, nothing earned.
				expect(TitlesService:getEquippedTitle(1)).to.equal(nil)
				expect(TitlesService:isEarned(1, "veteran")).to.equal(false)
			end)

			it("ROLLS BACK both legs together if the transaction fails after both mutators apply", function()
				-- A real cross-leg failure, not a mocked one: PlayerDataService:transaction()'s Phase 1
				-- (PlayerDataServiceServer.luau:917-1007) does not check IsActive, so BOTH the
				-- earned-removal and the equipped-clear mutators run; only the pre-commit check
				-- (PlayerDataServiceServer.luau:1163-1169) catches the inactive profile and calls
				-- rollbackAll. This is the case that would fail if revoke used two sequential mutate()
				-- calls instead of one transaction() — leg 1 would already be committed by the time leg
				-- 2 (or this check) ran.
				local profile = seed(1)
				TitlesService:award(1, "veteran")
				TitlesService:equip(1, "veteran")
				profile.IsActive = function()
					return false
				end

				local ok = TitlesService:revoke(1, "veteran")

				expect(ok).to.equal(false)
				expect(TitlesService:isEarned(1, "veteran")).to.equal(true)
				expect(TitlesService:getEquippedTitle(1)).to.equal("veteran")
			end)

			it("leaves the equipped title alone when revoking a DIFFERENT title", function()
				seed(1)
				TitlesService:award(1, "veteran")
				TitlesService:award(1, "champion")
				TitlesService:equip(1, "champion")
				expect(TitlesService:revoke(1, "veteran")).to.equal(true)
				expect(TitlesService:getEquippedTitle(1)).to.equal("champion")
			end)

			itMultiSlot("clears only the ACTIVE character's worn copy (other slots untouched)", function()
				local profile = seed(1)
				TitlesService:award(1, "veteran")
				TitlesService:equip(1, "veteran")

				-- Slot 2 independently wears the same title.
				profile.Data.account.titles.earned.champion = true
				profile.Data.slotState.active = 2
				TitlesService:equip(1, "champion")
				profile.Data.slots[2].equippedTitle.equipped = "veteran"

				-- The clear leg addresses ONLY the active slot's baked path...
				expect(TitlesService:revoke(1, "veteran")).to.equal(true)
				expect(profile.Data.slots[2].equippedTitle.equipped).to.equal(nil)
				-- ...so slot 1's worn copy is untouched history, tolerated like any retired id.
				expect(profile.Data.slots[1].equippedTitle.equipped).to.equal("veteran")
			end)

			it("refuses revoking a title the account has not earned", function()
				seed(1)
				local ok, reason = TitlesService:revoke(1, "veteran")
				expect(ok).to.equal(false)
				expect(reason).to.equal("not earned")
			end)

			it("reports a LOAD failure for an unloaded profile, never 'not earned'", function()
				local ok, reason = TitlesService:revoke(999, "veteran")
				expect(ok).to.equal(false)
				expect(reason).to.never.equal("not earned")
				expect(string.find(reason, "profile") ~= nil).to.equal(true)
			end)

			it("throws for an unregistered id", function()
				seed(1)
				expect(function()
					TitlesService:revoke(1, "deleted-long-ago")
				end).to.throw()
			end)
		end)

		describe("_onEquipRequest (trust boundary)", function()
			local fakePlayer = { UserId = 1, Name = "TestPlayer" } :: any

			it("equips an earned title from a well-formed payload", function()
				seed(1)
				TitlesService:award(1, "veteran")
				TitlesService._onEquipRequest({ titleId = "veteran" }, fakePlayer)
				expect(TitlesService:getEquippedTitle(1)).to.equal("veteran")
			end)

			it("silently drops a malformed payload without writing", function()
				seed(1)
				TitlesService:award(1, "veteran")
				TitlesService._onEquipRequest({ titleId = 42 }, fakePlayer)
				TitlesService._onEquipRequest(nil, fakePlayer)
				expect(TitlesService:getEquippedTitle(1)).to.equal(nil)
			end)

			it("refuses (without throwing) a well-formed request for an unearned title", function()
				seed(1)
				expect(function()
					TitlesService._onEquipRequest({ titleId = "champion" }, fakePlayer)
				end).to.never.throw()
				expect(TitlesService:getEquippedTitle(1)).to.equal(nil)
			end)

			it("refuses an UNREGISTERED title as a clean DEBUG log, never an ERROR/traceback", function()
				-- Discriminates the actual pre-fix bug: pre-fix, a well-formed-but-unregistered id
				-- reached equipImpl's assert, RequestHandler.wrap's xpcall caught the raise, and
				-- logged it at ERROR with a full debug.traceback (RequestHandler.luau's handler-error
				-- isolation path) — attacker-triggerable log spam, up to 10 times per 10s per client.
				-- `expect(fn).to.never.throw()` alone cannot see this: `_onEquipRequest` IS the
				-- `wrap(...)` return value, so its own internal xpcall already swallows the raise in
				-- BOTH the pre-fix and post-fix worlds, and `getEquippedTitle` is `nil` either way
				-- (equipImpl's mutate is never reached in either world for an unregistered id). The
				-- only observable difference is HOW the refusal was recorded — captured here via
				-- Logger.subscribe, the RequestHandler.spec.luau "wrap — audit logging" precedent.
				seed(1)
				local captured: { Logger.LogEntry } = {}
				local unsubscribe = Logger.subscribe(function(entry)
					table.insert(captured, entry)
				end)
				TitlesService._onEquipRequest({ titleId = "not-a-title" }, fakePlayer)
				unsubscribe()

				local sawError = false
				local sawCleanDebugRefusal = false
				for _, entry in captured do
					if entry.level == "ERROR" then
						sawError = true
					end
					if entry.level == "DEBUG" and string.find(entry.message, "not-a-title", 1, true) then
						sawCleanDebugRefusal = true
					end
				end
				-- Pre-fix: sawError == true, sawCleanDebugRefusal == false — this assertion FAILS.
				expect(sawError).to.equal(false)
				expect(sawCleanDebugRefusal).to.equal(true)
				expect(TitlesService:getEquippedTitle(1)).to.equal(nil)
			end)
		end)

		describe("guarding", function()
			-- 0, not -1: -1 is a valid Studio test-player id (Guard.userIdForSession).
			it("throws for a malformed userId", function()
				expect(function()
					TitlesService:getEarned(0)
				end).to.throw()
			end)

			it("throws for an unregistered title id (programmer error, unlike validation)", function()
				seed(1)
				expect(function()
					TitlesService:isEarned(1, "deleted-long-ago")
				end).to.throw()
			end)
		end)
	end)
end
