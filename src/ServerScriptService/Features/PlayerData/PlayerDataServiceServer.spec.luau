--!strict
--[=[
	Unit tests for PlayerDataServiceServer:mutate() and :transaction().

	Unlike the domain-service specs (which mock PlayerDataService), these exercise the
	REAL mutate/transaction logic by seeding fake, ProfileStore-shaped profiles through
	the `_setProfileForTesting` seam. The fakes implement only the slice of the Profile
	API that the service touches: Data, LastSavedData, IsActive(), Save(), OnSave,
	OnAfterSave. Save() snapshots Data into LastSavedData and fires OnAfterSave
	synchronously, mirroring ProfileStore's rollback contract — so no yielding is needed.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataPathUtils = require(PlayerDataServer.Utils.PlayerDataPathUtils)
local CurrencyService = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local InventoryService = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local sift = require(ReplicatedStorage.Packages.sift)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)

-- Minimal synchronous signal: enough for OnSave/OnAfterSave Connect/Fire/Disconnect.
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
			-- Snapshot first so a handler disconnecting itself mid-fire is safe.
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

-- `opts` lets a test simulate the two failure modes transaction() must handle at commit time:
--   activeUntilCall — IsActive() returns false once it has been called more than this many times,
--     so a profile can be active during pre-save yet inactive at the commit gate.
--   saveFailFrom    — Save() throws on its Nth call onward, so pre-save can succeed (establishing
--     LastSavedData) while the later commit save fails.
--   suppressAfterSave — Save() returns cleanly but never fires OnAfterSave, mirroring ProfileStore's
--     real fire-and-forget Save(): the dispatch succeeded but the UpdateAsync never landed (DataStore
--     outage). persist=true must treat this as NOT durable.
type FakeProfileOpts = { activeUntilCall: number?, saveFailFrom: number?, suppressAfterSave: boolean? }

local function makeFakeProfile(data: any, opts: FakeProfileOpts?)
	local o = opts or {}
	local isActiveCalls = 0
	local saveCalls = 0
	local profile: any = {
		Data = data,
		LastSavedData = sift.Dictionary.copyDeep(data),
		OnSave = fakeSignal(),
		OnAfterSave = fakeSignal(),
	}
	function profile:IsActive(): boolean
		isActiveCalls += 1
		if o.activeUntilCall and isActiveCalls > o.activeUntilCall then
			return false
		end
		return true
	end
	function profile:Save()
		saveCalls += 1
		if o.saveFailFrom and saveCalls >= o.saveFailFrom then
			error("simulated save failure")
		end
		self.LastSavedData = sift.Dictionary.copyDeep(self.Data)
		self.OnSave:Fire()
		if not o.suppressAfterSave then
			self.OnAfterSave:Fire()
		end
	end
	-- Test seam: how many times Save() was called, so a spec can assert a default (non-persist)
	-- transaction forces no save.
	function profile:_getSaveCalls(): number
		return saveCalls
	end
	return profile
end

-- The ONE profile fixture: the real slot-aware shape. Every slot is its OWN table (so a write to one
-- can be asserted not to surface in another) seeded with the registered template defaults (currency
-- coins = 100, an empty inventory — see the PlayerDataSliceSystem.registerSlot calls in
-- CurrencyServiceServer / InventoryServiceServer), with the currency under test stamped into the
-- ACTIVE slot. Same fixture shape as CurrencyServiceServer.spec / InventoryServiceServer.spec.
--
-- There is deliberately NO flat (pre-slots) fixture: a bare root key still RESOLVES (the resolver
-- treats the profile as the container), but for a synced slice name the mirror reads
-- `profile.slots[profile.slotState.active].<slice>` — so a flat profile would throw inside mutate()'s
-- mirror step. Slice paths are dotted; only genuine root keys (`_schemaVersion`, `slotState`) are bare.
--
-- Every non-active slot (only present when MAX_SLOTS >= 2) carries the registered template default
-- (coins = 100 — see SLOT_2_COINS in the "slotState" describe, which switches onto slot 2 and reads that
-- value back through CurrencyService).
local function makeSlotData(coins: number): PlayerDataTypes.PlayerProfile
	local slots: { PlayerDataTypes.PlayerSlot } = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = {
			currency = { coins = 100 },
			inventory = { items = {} },
			equippedTitle = {},
		}
	end
	slots[1] = {
		currency = { coins = coins },
		inventory = { items = {} },
		equippedTitle = {},
	}
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			itemMint = { nextUid = 1 },
			premium = { balance = 0 },
			receipts = { ids = {} },
			entitlements = { owned = {} },
			settings = { values = {} },
			titles = { earned = {} },
		},
		slots = slots,
	}
end

-- The dotted paths every test below writes through. The active slot is 1 in every fixture, so
-- CURRENCY_PATH / INVENTORY_PATH are the ACTIVE slot's slices (the ones that mirror).
local CURRENCY_PATH = PlayerDataPathUtils.forSlot("currency", 1)
local INVENTORY_PATH = PlayerDataPathUtils.forSlot("inventory", 1)
-- An account-wide slice path (InventoryServiceServer registers "itemMint" with a validator requiring an
-- integer nextUid >= 1).
local ITEM_MINT_PATH = PlayerDataPathUtils.forAccount("itemMint")

-- The active slot's tables — the slot-aware spelling of the old flat `profile.Data.currency`. Mirrors
-- the sibling domain specs' activeSlotOf().
local function activeSlotOf(profile: any): any
	return profile.Data.slots[profile.Data.slotState.active]
end

-- Session-capable fake: extends makeFakeProfile with the members _startSession touches
-- (AddUserId, Reconcile, EndSession, OnSessionEnd), mirroring ProfileStore's session contract.
local function makeFakeSessionProfile(data: any, opts: FakeProfileOpts?)
	local profile = makeFakeProfile(data, opts)
	profile.OnSessionEnd = fakeSignal()
	local addedUserIds: { number } = {}
	local sessionEnded = false
	function profile:AddUserId(userId: number)
		table.insert(addedUserIds, userId)
	end
	function profile:Reconcile()
		-- Mirror ProfileStore's backfill for the one template field the lifecycle depends on:
		-- _schemaVersion, stamped at CURRENT_VERSION by the real template. _startSession must
		-- read the stored version BEFORE this runs (the backfill would mask an old profile).
		if self.Data._schemaVersion == nil then
			self.Data._schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION
		end
	end
	function profile:EndSession()
		sessionEnded = true
	end
	function profile:_getAddedUserIds(): { number }
		return addedUserIds
	end
	function profile:_wasSessionEnded(): boolean
		return sessionEnded
	end
	return profile
end

-- The fake side of the SessionHost seam: records kicks and lets a test toggle presence.
local function makeFakeHost(userId: number)
	local kicks: { string } = {}
	local present = true
	return {
		userId = userId,
		name = `TestPlayer{userId}`,
		isPresent = function()
			return present
		end,
		kick = function(message: string)
			table.insert(kicks, message)
		end,
		_kicks = kicks,
		_setPresent = function(value: boolean)
			present = value
		end,
	}
end

return function()
	-- Multi-slot behaviour is dormant while MAX_SLOTS = 1; these re-enable when a game raises it.
	local itMultiSlot = if PlayerDataConstants.MAX_SLOTS >= 2 then it else itSKIP

	describe("PlayerDataServiceServer", function()
		local profiles: { [number]: any } = {}
		local prevLogLevel: Logger.LogLevel

		beforeAll(function()
			-- Silence audit/debug noise from the real mutate/transaction paths.
			prevLogLevel = Logger.getGlobalLevel()
			Logger.setGlobalLevel("NONE")
		end)

		afterAll(function()
			Logger.setGlobalLevel(prevLogLevel)
		end)

		beforeEach(function()
			profiles = {}
		end)

		afterEach(function()
			-- Clear seeded profiles from the real registry, and their StateSyncServerStore mirror, so
			-- specs stay isolated (mutate()/transaction() write into StateSyncServerStore as a side effect).
			for userId in profiles do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
			end
			profiles = {}
		end)

		-- Seeds a slot-shaped profile WITHOUT mirroring it into StateSyncServerStore, so a test can assert that a
		-- rejected write left the atom empty (`StateSyncServerStore.currencies()[userId] == nil`).
		local function seed(userId: number, coins: number)
			local profile = makeFakeProfile(makeSlotData(coins))
			profiles[userId] = profile
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile
		end

		-- Register a pre-built fake profile (used for the failure-mode fakes above).
		local function seedProfile(userId: number, profile: any)
			profiles[userId] = profile
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile
		end

		-- Seeds a profile AND mirrors it into StateSyncServerStore exactly as a real profile load does
		-- (_startSession's syncFromProfile), so a spec can assert what the atom held BEFORE a write —
		-- the only way to prove a non-active-slot write left the mirror alone.
		local function seedSlotProfile(userId: number, coins: number)
			local profile = seed(userId, coins)
			StateSyncServerStore.syncFromProfile(userId, profile.Data)
			return profile
		end

		-- =====================================================================
		describe("mutate", function()
			it("applies the mutation and returns true", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 250
					return true
				end)
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).currency.coins).to.equal(250)
			end)

			it("mirrors only the mutated slice into StateSyncServerStore, not every synced slice (A2)", function()
				seed(1, 100)
				StateSyncServerStore.setInventory(1, { { itemType = "shield", quantity = 1 } })
				local inventoryBefore = StateSyncServerStore.inventories()

				PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 250
					return true
				end)

				expect(StateSyncServerStore.currencies()[1].coins).to.equal(250)
				-- Mutating "currency" must not touch the inventory atom at all.
				expect(StateSyncServerStore.inventories()).to.equal(inventoryBefore)
			end)

			it("rolls back writes when the mutator reports no change (false = no change is ENFORCED)", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 999 -- writes, then aborts
					return false
				end)
				expect(ok).to.equal(false)
				-- The write is rolled back from the pre-mutate snapshot, so the returned flag and
				-- the stored state agree — the dirty 999 can never ride the next auto-save.
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("rejects a mutator that yields and leaves the slice untouched", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					task.wait() -- contract violation: mutators must be synchronous
					c.coins = 999
					return true
				end)
				expect(ok).to.equal(false)
				-- Rejected before the write, so the slice is untouched and never mirrored.
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
				expect(StateSyncServerStore.currencies()[1]).to.equal(nil)
			end)

			it("rolls back a mutator that writes and THEN yields (regression)", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 999 -- the write lands before the contract violation...
					task.wait()
					return true
				end)
				expect(ok).to.equal(false)
				-- ...and must be restored from the snapshot, not left to persist via auto-save.
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
				expect(StateSyncServerStore.currencies()[1]).to.equal(nil)
			end)

			it("rejects a mutator that errors without crashing the caller", function()
				local profile = seed(1, 100)
				local ok: boolean? = nil
				expect(function()
					ok = PlayerDataService:mutate(1, CURRENCY_PATH, function()
						error("boom")
					end)
				end).never.to.throw()
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("rolls back a mutator that writes and THEN errors (regression)", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 999
					error("boom after writing")
				end)
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("returns false when the profile is not loaded", function()
				expect(PlayerDataService:mutate(404, CURRENCY_PATH, function()
					return true
				end)).to.equal(false)
			end)

			it("returns false when the path does not exist", function()
				seed(1, 100)
				expect(PlayerDataService:mutate(1, "quests", function()
					return true
				end)).to.equal(false)
			end)

			it("returns false (does not throw) for an empty path", function()
				seed(1, 100)
				expect(function()
					expect(PlayerDataService:mutate(1, "", function()
						return true
					end)).to.equal(false)
				end).never.to.throw()
			end)

			it("throws for a non-number userId", function()
				expect(function()
					PlayerDataService:mutate("bad" :: any, CURRENCY_PATH, function()
						return true
					end)
				end).to.throw()
			end)

			it("refuses a write to a profile whose session is no longer active", function()
				-- activeUntilCall = 0 makes IsActive() return false on its first call — the state a
				-- profile is in after its session ended but before _cleanupPlayer removed the entry.
				local profile = seedProfile(1, makeFakeProfile(makeSlotData(100), { activeUntilCall = 0 }))
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 250
					return true
				end)
				expect(ok).to.equal(false)
				-- No doomed write, and nothing mirrored to the client.
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
				expect(StateSyncServerStore.currencies()[1]).to.equal(nil)
			end)
		end)

		-- =====================================================================
		-- The "currency"/"inventory" slices register data-layer invariant validators (cap /
		-- non-negative / size). These run AFTER a mutator and roll the write back on violation, so the
		-- cap holds no matter which path built the write — including a raw transaction op that never
		-- went through the owning service's capped methods.
		describe("slice invariant validators", function()
			it("mutate rolls back a currency write that goes negative", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = -5
					return true
				end)
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
				expect(StateSyncServerStore.currencies()[1]).to.equal(nil)
			end)

			it("mutate rolls back a currency write above MAX_CURRENCY", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 2_000_000_000 -- MAX_CURRENCY is 1e9
					return true
				end)
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("mutate() returns the validator's reason as a second value on invariant rejection", function()
				seed(1, 100)
				local changed, reason = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = -5 -- validator rejects negative
					return true
				end)
				expect(changed).to.equal(false)
				expect(type(reason)).to.equal("string")
			end)

			it("mutate() returns nil reason when the mutator itself aborts (business-logic false)", function()
				seed(1, 100)
				local changed, reason = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 999 -- writes, then aborts
					return false
				end)
				expect(changed).to.equal(false)
				expect(reason).to.equal(nil)
			end)

			it("transaction rolls the WHOLE txn back when a raw op breaches the currency cap", function()
				local profile = seed(1, 100)
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = -1 -- a hand-built op bypassing removeCurrency's floor
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(result.committed).to.equal(false)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("transaction() populates rejectionReason and rejectedPath on validator rejection", function()
				seed(1, 100)
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = -1 -- a hand-built op bypassing removeCurrency's floor
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(type(result.rejectionReason)).to.equal("string")
				expect(result.rejectedPath).to.equal(CURRENCY_PATH)
			end)

			it("transaction() leaves rejectionReason nil on a business-logic abort", function()
				seed(1, 100)
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function()
							return false
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(result.rejectionReason).to.equal(nil)
				expect(result.rejectedPath).to.equal(nil)
			end)

			-- There is no global MAX_INVENTORY_SIZE: the size invariant is a PER-KIND cap
			-- (ItemConstants.KIND_CAPS), enforced by validateInventory. "scrap" is misc
			-- (KIND_CAPS.misc == 40), so 41 single-quantity entries of it breach the cap.
			it("transaction rolls back a raw op that breaches a per-kind cap (KIND_CAPS)", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = INVENTORY_PATH,
						mutator = function(inv: any)
							for _ = 1, 41 do
								table.insert(inv.items, { itemType = "scrap", quantity = 1 })
							end
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				-- The oversized write was rolled back to the empty seeded inventory.
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)

			-- The validators enforce the FULL slice invariant, not just numeric range / size — the
			-- guarantee the owning services document ("holds for ANY path into the slice") must match
			-- what a raw op can actually get past them.
			it("mutate rolls back a write that adds an unregistered currency key", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.dogecoin = 5 -- not in CURRENCIES; must never persist or replicate
					return true
				end)
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).currency.dogecoin).to.equal(nil)
				expect(StateSyncServerStore.currencies()[1]).to.equal(nil)
			end)

			it("transaction rolls back a raw op that inserts an unregistered itemType", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = INVENTORY_PATH,
						mutator = function(inv: any)
							table.insert(inv.items, { itemType = "not-a-real-item", quantity = 1 })
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)

			it("transaction rolls back a raw op that writes a non-positive stack quantity", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = INVENTORY_PATH,
						mutator = function(inv: any)
							-- "medkit" is stackable (declares stackMax); "wrench" (a tool) is NOT
							-- stackable and would fail validation for an entirely different reason (a
							-- quantity field on a unique entry) — see the "unique item carries a
							-- quantity" case below, which covers that shape separately.
							table.insert(inv.items, { itemType = "medkit", quantity = -5 })
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)

			it("mutate rolls back an inventory write with a non-string uid", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, INVENTORY_PATH, function(inv: any)
					table.insert(inv.items, { itemType = "golden-wrench", uid = 123 })
					return true
				end)
				expect(ok).to.equal(false)
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)

			-- The three shape/uniqueness rules validateInventory adds on top of the
			-- registration/size checks above: a stackable entry must not carry a `uid`, a unique entry
			-- must not carry a `quantity`, and every `uid` in the array must be unique.
			it("mutate rolls back a stackable entry that also carries a uid", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, INVENTORY_PATH, function(inv: any)
					table.insert(inv.items, { itemType = "medkit", quantity = 1, uid = "bogus" })
					return true
				end)
				expect(ok).to.equal(false)
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)

			it("mutate rolls back a unique entry that also carries a quantity", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, INVENTORY_PATH, function(inv: any)
					table.insert(inv.items, { itemType = "golden-wrench", uid = "u1", quantity = 1 })
					return true
				end)
				expect(ok).to.equal(false)
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)

			it("mutate rolls back a duplicate uid within the array", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, INVENTORY_PATH, function(inv: any)
					table.insert(inv.items, { itemType = "golden-wrench", uid = "dup" })
					table.insert(inv.items, { itemType = "hard-hat", uid = "dup" })
					return true
				end)
				expect(ok).to.equal(false)
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)

			-- validateInventory must be TOTAL (never throw) because mutate()/transaction() call
			-- validators directly, with no pcall around them (see the data-layer's "must be total"
			-- contract). A raw op that leaves `inventory.items` as something other than a table used to
			-- make validateInventory's `for index, entry in inventory.items` throw instead of
			-- returning (false, reason) — this proves the fix: a rejected write, not a script error.
			it("mutate rolls back (does not throw) when a raw op sets inventory.items to a non-table", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, INVENTORY_PATH, function(inv: any)
					inv.items = "not-a-table"
					return true
				end)
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).inventory.items).to.be.a("table")
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)

			it("mutate rolls back (does not throw) when a raw op sets inventory.items to nil", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, INVENTORY_PATH, function(inv: any)
					inv.items = nil
					return true
				end)
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).inventory.items).to.be.a("table")
				expect(#activeSlotOf(profile).inventory.items).to.equal(0)
			end)
		end)

		-- =====================================================================
		-- The mutatorInFlight guard: every nested mutate()/transaction() from inside a mutator is
		-- refused — including on profiles the outer call does NOT touch, which the per-profile
		-- re-entry guard can't see. Without this, a nested write on an unaffected profile commits
		-- outside the outer transaction's snapshots and would survive its rollback.
		describe("nested data-layer calls from inside a mutator", function()
			it("refuses a nested mutate() on an unrelated profile", function()
				seed(1, 100)
				local other = seed(2, 100)
				local nestedResult: boolean? = nil
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					nestedResult = PlayerDataService:mutate(2, CURRENCY_PATH, function(c2: any)
						c2.coins = 999
						return true
					end)
					c.coins = 150
					return true
				end)
				-- The nested call is refused and writes nothing; the outer mutation itself is valid
				-- and commits normally.
				expect(nestedResult).to.equal(false)
				expect(activeSlotOf(other).currency.coins).to.equal(100)
				expect(ok).to.equal(true)
			end)

			it("refuses a nested transaction() from inside a mutate() mutator", function()
				seed(1, 100)
				local other = seed(2, 100)
				local nestedOk: boolean? = nil
				PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					nestedOk = PlayerDataService:transaction({
						{
							userId = 2,
							path = CURRENCY_PATH,
							mutator = function(c2: any)
								c2.coins = 999
								return true
							end,
						},
					})
					c.coins = 150
					return true
				end)
				expect(nestedOk).to.equal(false)
				expect(activeSlotOf(other).currency.coins).to.equal(100)
			end)

			it("a transaction op cannot leak a write to a THIRD profile past its own rollback (regression)", function()
				-- The exact atomicity gap this guard closes: op 1 pays an "escrow" profile the
				-- transaction does not touch, then op 2 aborts. Before the guard, the escrow payment
				-- was in no snapshot and survived the rollback — a durable, asymmetric write.
				local a = seed(1, 100)
				local b = seed(2, 100)
				local escrow = seed(3, 100)
				local escrowPayment: boolean? = nil
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							escrowPayment = PlayerDataService:mutate(3, CURRENCY_PATH, function(c3: any)
								c3.coins += 50
								return true
							end)
							c.coins -= 50
							return true
						end,
					},
					{
						userId = 2,
						path = CURRENCY_PATH,
						mutator = function()
							return false -- abort: everything above must unwind
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(result.committed).to.equal(false)
				-- The nested escrow write was refused outright, so nothing survived the rollback.
				expect(escrowPayment).to.equal(false)
				expect(activeSlotOf(a).currency.coins).to.equal(100)
				expect(activeSlotOf(b).currency.coins).to.equal(100)
				expect(activeSlotOf(escrow).currency.coins).to.equal(100)
			end)

			it("clears the guard after every outcome, so subsequent mutations work", function()
				local profile = seed(1, 100)
				-- Rejected outcomes: a yielding mutator and an erroring mutator both pass through the
				-- guarded resume; the flag must never leak set (it would refuse ALL future writes).
				PlayerDataService:mutate(1, CURRENCY_PATH, function()
					task.wait()
					return true
				end)
				PlayerDataService:mutate(1, CURRENCY_PATH, function()
					error("boom")
				end)
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 123
					return true
				end)
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).currency.coins).to.equal(123)
			end)
		end)

		-- =====================================================================
		describe("getState", function()
			it("reports session diagnostics (not slice values) for loaded profiles", function()
				seed(1, 100)
				local state = PlayerDataService:getState()
				local session = state.sessions["1"]
				expect(session).to.be.ok()
				expect(session.hasData).to.equal(true)
				expect(session.active).to.equal(true)
				expect(session.inTransaction).to.equal(false)
				-- Slice values are deliberately absent — the reactive atoms are their window.
				expect(session.currency).to.equal(nil)
			end)

			it("reports inTransaction = true while a transaction holds the profile's lock", function()
				seed(1, 100)
				local observed: boolean? = nil
				PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							observed = PlayerDataService:getState().sessions["1"].inTransaction
							c.coins = 1
							return true
						end,
					},
				})
				expect(observed).to.equal(true)
				-- Lock released after commit.
				expect(PlayerDataService:getState().sessions["1"].inTransaction).to.equal(false)
			end)
		end)

		-- =====================================================================
		describe("getProfile", function()
			it("returns a frozen snapshot, not the live profile data", function()
				local profile = seed(1, 100)
				-- Seed an inventory item so the per-item freeze loop is exercised too.
				table.insert(activeSlotOf(profile).inventory.items, { itemType = "medkit", quantity = 5 })
				local snap = PlayerDataService:getProfile(1)
				expect(snap).to.be.ok()
				-- A distinct copy, not the live table...
				expect(snap).never.to.equal(profile.Data)
				-- ...and deep-frozen at EVERY level — through the slots array, into a slot's nested
				-- slice, and into an inventory entry — so an attempt to bypass mutate() by writing to
				-- any of them throws instead of silently corrupting state.
				expect(table.isfrozen(snap :: any)).to.equal(true)
				expect(table.isfrozen((snap :: any).slots)).to.equal(true)
				expect(function()
					(snap :: any).slots[1].currency.coins = 1
				end).to.throw()
				expect(function()
					(snap :: any).slots[1].inventory.items[1].quantity = 999
				end).to.throw()
				expect(function()
					(snap :: any).account.itemMint.nextUid = 3
				end).to.throw()
				-- The live profile is untouched by the read.
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
				expect(activeSlotOf(profile).inventory.items[1].quantity).to.equal(5)
			end)

			it("returns nil for an unloaded profile", function()
				expect(PlayerDataService:getProfile(404)).to.equal(nil)
			end)
		end)

		-- =====================================================================
		-- The single-slice read path behind PlayerDataSliceSystem.get: getProfile's frozen-copy guarantee at
		-- O(slice) cost. Internal plumbing, but the guarantees are load-bearing (getCurrency /
		-- getInventory read through it), so they are pinned here.
		describe("_getSlotShell / _getAccountShell", function()
			it("swaps ONLY the requested slice of the requested SLOT for a frozen deep copy", function()
				local profile = seedSlotProfile(1, 100)
				-- The LAST slot: with MAX_SLOTS >= 2 that is a non-active slot; with one slot it is slot 1.
				local slotIndex = PlayerDataConstants.MAX_SLOTS
				local slot = profile.Data.slots[slotIndex]
				table.insert(slot.inventory.items, { itemType = "medkit", quantity = 5 })
				local shell = PlayerDataService:_getSlotShell(1, slotIndex, "currency")
				expect(shell).to.be.ok()
				-- The shell is a fresh table, and the requested slice is a distinct, deep-frozen copy —
				-- writing through it throws instead of corrupting live state.
				expect(shell).never.to.equal(slot)
				expect((shell :: any).currency).never.to.equal(slot.currency)
				expect(table.isfrozen((shell :: any).currency)).to.equal(true)
				expect(function()
					(shell :: any).currency.coins = 1
				end).to.throw()
				-- The OTHER slices are intentionally NOT copied — that is what makes this O(slice)
				-- (the shell must be dropped right after the slice is projected out; see the contract).
				expect((shell :: any).inventory).to.equal(slot.inventory)
				-- The live profile is untouched and stays mutable for mutate().
				expect(slot.currency.coins).to.equal(100)
				expect(table.isfrozen(slot.currency)).to.equal(false)
			end)

			itMultiSlot("reads the requested slot, not the active one", function()
				local profile = seedSlotProfile(1, 100)
				profile.Data.slots[2].currency.coins = 42 -- the active slot is 1
				expect(((PlayerDataService:_getSlotShell(1, 2, "currency") :: any).currency).coins).to.equal(42)
			end)

			it("returns nil for an unloaded profile, an out-of-range slot, and a missing slice", function()
				expect(PlayerDataService:_getSlotShell(404, 1, "currency")).to.equal(nil)
				seedSlotProfile(1, 100)
				expect(PlayerDataService:_getSlotShell(1, 9, "currency")).to.equal(nil)
				expect(PlayerDataService:_getSlotShell(1, 1, "quests")).to.equal(nil)
			end)

			it("throws for a non-number slotIndex (boundary guard, matches userId/slice)", function()
				seedSlotProfile(1, 100)
				expect(function()
					PlayerDataService:_getSlotShell(1, "2" :: any, "currency")
				end).to.throw()
				expect(function()
					PlayerDataService:_getSlotShell(1, nil :: any, "currency")
				end).to.throw()
				-- A valid slotIndex still works.
				expect(PlayerDataService:_getSlotShell(1, 1, "currency")).to.be.ok()
			end)

			it("swaps ONLY the requested account slice for a frozen deep copy", function()
				local profile = seedSlotProfile(1, 100)
				local shell = PlayerDataService:_getAccountShell(1, "itemMint")
				expect(shell).to.be.ok()
				expect((shell :: any).itemMint).never.to.equal(profile.Data.account.itemMint)
				expect(table.isfrozen((shell :: any).itemMint)).to.equal(true)
				expect((shell :: any).itemMint.nextUid).to.equal(1)
				expect(table.isfrozen(profile.Data.account.itemMint)).to.equal(false)
			end)

			it("returns nil for an unloaded profile and for a missing account slice", function()
				expect(PlayerDataService:_getAccountShell(404, "itemMint")).to.equal(nil)
				seedSlotProfile(1, 100)
				expect(PlayerDataService:_getAccountShell(1, "no-such-slice")).to.equal(nil)
			end)

			it(
				"serves PlayerDataSliceSystem reads end-to-end: getCurrency returns a frozen per-slice snapshot",
				function()
					local profile = seedSlotProfile(1, 100)
					local currency = CurrencyService:getCurrency(1)
					expect(currency).to.be.ok()
					expect((currency :: any).coins).to.equal(100)
					expect(currency :: any).never.to.equal(profile.Data.slots[1].currency)
					expect(table.isfrozen(currency :: any)).to.equal(true)
					expect(function()
						(currency :: any).coins = 999
					end).to.throw()
				end
			)
		end)

		-- =====================================================================
		-- Dotted paths: `slots.2.currency` / `account.itemMint`. Two semantics are load-bearing
		-- and easy to get wrong, so they are pinned here: the slice invariant must hold on EVERY slot
		-- (the validator is registered once, per PATTERN), and the StateSyncServerStore mirror is keyed by SLICE
		-- NAME and holds the ACTIVE slot only — so a write aimed at a non-active slot must not mirror.
		-- Cases that need a second slot are gated on MAX_SLOTS >= 2.
		describe("slot-aware paths", function()
			local USER_ID = 1

			beforeEach(function()
				seedSlotProfile(USER_ID, 100)
			end)

			it("mutates the active slot's slice through a dotted path", function()
				local ok = PlayerDataService:mutate(
					USER_ID,
					PlayerDataPathUtils.forSlot("currency", 1),
					function(currency: any)
						currency.coins += 50
						return true
					end
				)
				expect(ok).to.equal(true)
				expect((PlayerDataService:getProfile(USER_ID) :: any).slots[1].currency.coins).to.equal(150)
			end)

			itMultiSlot("keeps slots independent — writing slot 1 does not touch slot 2", function()
				PlayerDataService:mutate(USER_ID, PlayerDataPathUtils.forSlot("currency", 1), function(currency: any)
					currency.coins = 777
					return true
				end)
				expect((PlayerDataService:getProfile(USER_ID) :: any).slots[2].currency.coins).to.equal(100)
			end)

			itMultiSlot("enforces the slice invariant on a NON-first slot", function()
				local ok = PlayerDataService:mutate(
					USER_ID,
					PlayerDataPathUtils.forSlot("currency", 2),
					function(currency: any)
						currency.coins = -1
						return true
					end
				)
				expect(ok).to.equal(false)
				expect((PlayerDataService:getProfile(USER_ID) :: any).slots[2].currency.coins).to.equal(100)
			end)

			it("mirrors a write to the ACTIVE slot into StateSyncServerStore", function()
				PlayerDataService:mutate(USER_ID, PlayerDataPathUtils.forSlot("currency", 1), function(currency: any)
					currency.coins = 500
					return true
				end)
				expect((StateSyncServerStore.snapshot("currency")[USER_ID] :: any).coins).to.equal(500)
			end)

			itMultiSlot("does NOT mirror a write to an INACTIVE slot", function()
				-- The active slot is 1; the atom must keep showing slot 1's value.
				local before = (StateSyncServerStore.snapshot("currency")[USER_ID] :: any).coins
				PlayerDataService:mutate(USER_ID, PlayerDataPathUtils.forSlot("currency", 2), function(currency: any)
					currency.coins = 4242
					return true
				end)
				expect((StateSyncServerStore.snapshot("currency")[USER_ID] :: any).coins).to.equal(before)
				-- ...while the write itself DID land on slot 2.
				expect((PlayerDataService:getProfile(USER_ID) :: any).slots[2].currency.coins).to.equal(4242)
			end)

			it("mutates an account slice", function()
				local ok = PlayerDataService:mutate(USER_ID, ITEM_MINT_PATH, function(mint: any)
					mint.nextUid += 1
					return true
				end)
				expect(ok).to.equal(true)
				expect((PlayerDataService:getProfile(USER_ID) :: any).account.itemMint.nextUid).to.equal(2)
			end)

			it("returns the active slot", function()
				expect(PlayerDataService:getActiveSlot(USER_ID)).to.equal(1)
				expect(PlayerDataService:getActiveSlot(404)).to.equal(nil)
			end)

			it("returns the slot epoch", function()
				expect(PlayerDataService:getSlotEpoch(USER_ID)).to.equal(1)
				expect(PlayerDataService:getSlotEpoch(404)).to.equal(nil)
			end)

			it("rejects an unknown path without mutating", function()
				local ok = PlayerDataService:mutate(USER_ID, "slots.9.currency", function()
					return true
				end)
				expect(ok).to.equal(false)
			end)

			it("rolls back a transaction spanning an account slice and a slot slice", function()
				local result = PlayerDataService:transaction({
					{
						userId = USER_ID,
						path = PlayerDataPathUtils.forSlot("currency", 1),
						mutator = function(currency: any)
							currency.coins = 999
							return true
						end,
					},
					{
						userId = USER_ID,
						path = ITEM_MINT_PATH,
						mutator = function()
							return false -- abort the whole transaction
						end,
					},
				})
				expect(result).to.equal(false)
				expect((PlayerDataService:getProfile(USER_ID) :: any).slots[1].currency.coins).to.never.equal(999)
			end)

			itMultiSlot("rolls back a transaction op on a NON-active slot (rollback re-resolves the path)", function()
				local profile = profiles[USER_ID]
				local ok = PlayerDataService:transaction({
					{
						userId = USER_ID,
						path = PlayerDataPathUtils.forSlot("currency", 2),
						mutator = function(currency: any)
							currency.coins = 1
							return true
						end,
					},
					{
						userId = USER_ID,
						path = PlayerDataPathUtils.forSlot("currency", 1),
						mutator = function()
							return false
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(profile.Data.slots[2].currency.coins).to.equal(100)
				expect(profile.Data.slots[1].currency.coins).to.equal(100)
			end)

			itMultiSlot("mirrors an ACTIVE-slot transaction op but not an inactive-slot one", function()
				local ok = PlayerDataService:transaction({
					{
						userId = USER_ID,
						path = PlayerDataPathUtils.forSlot("currency", 1),
						mutator = function(currency: any)
							currency.coins = 300
							return true
						end,
					},
					{
						userId = USER_ID,
						path = PlayerDataPathUtils.forSlot("currency", 2),
						mutator = function(currency: any)
							currency.coins = 900
							return true
						end,
					},
				})
				expect(ok).to.equal(true)
				-- Both ops committed; only the active slot's value reached the atom.
				expect((StateSyncServerStore.snapshot("currency")[USER_ID] :: any).coins).to.equal(300)
			end)
		end)

		-- =====================================================================
		-- The active slot is a TABLE (`slotState = { active = n }`), not a bare number, because mutate()
		-- hands the mutator the VALUE at the path and expects IN-PLACE mutation — a number cannot be
		-- mutated by reference, so a scalar path is read-only through the data layer. These tests are the
		-- proof: they would be impossible to write against a bare `activeSlot: number`. Switching needs a
		-- second slot, so those cases are gated on MAX_SLOTS >= 2.
		describe("slotState", function()
			local USER_ID = 1
			-- makeSlotData seeds every NON-active slot (when MAX_SLOTS >= 2) with the registered template
			-- default (coins = 100) and stamps the value under test into slot 1 — so 555 vs 100 tells the
			-- two slots apart.
			local SLOT_1_COINS = 555
			local SLOT_2_COINS = 100

			beforeEach(function()
				seedSlotProfile(USER_ID, SLOT_1_COINS)
			end)

			itMultiSlot("the active slot is WRITABLE through mutate (a scalar path is not)", function()
				local ok = PlayerDataService:mutate(USER_ID, "slotState", function(slotState: any)
					slotState.active = 2
					return true
				end)
				expect(ok).to.equal(true)
				expect(PlayerDataService:getActiveSlot(USER_ID)).to.equal(2)
			end)

			itMultiSlot("changing the active slot changes which slot a slice read resolves to", function()
				expect(CurrencyService:getCurrencyAmount(USER_ID, "coins")).to.equal(SLOT_1_COINS)

				PlayerDataService:mutate(USER_ID, "slotState", function(slotState: any)
					slotState.active = 2
					return true
				end)

				-- PlayerDataSliceSystem resolves the active slot at call time, so currency now reads slot 2's value.
				expect(CurrencyService:getCurrencyAmount(USER_ID, "coins")).to.equal(SLOT_2_COINS)
			end)

			itMultiSlot("moves the mirror gate: after a switch, slot 2's writes mirror and slot 1's do not", function()
				PlayerDataService:mutate(USER_ID, "slotState", function(slotState: any)
					slotState.active = 2
					return true
				end)

				PlayerDataService:mutate(USER_ID, PlayerDataPathUtils.forSlot("currency", 2), function(currency: any)
					currency.coins = 4242
					return true
				end)
				expect((StateSyncServerStore.snapshot("currency")[USER_ID] :: any).coins).to.equal(4242)

				-- Slot 1 is now the INACTIVE slot: its write commits but must not reach the atom.
				PlayerDataService:mutate(USER_ID, PlayerDataPathUtils.forSlot("currency", 1), function(currency: any)
					currency.coins = 1
					return true
				end)
				expect((StateSyncServerStore.snapshot("currency")[USER_ID] :: any).coins).to.equal(4242)
				expect((PlayerDataService:getProfile(USER_ID) :: any).slots[1].currency.coins).to.equal(1)
			end)

			-- slotState is registered by the core skeleton (PlayerDataConstants.registerRootPath), so its
			-- invariant is enforced by the DATA LAYER — not by any slot-switch flow's pre-flight guards.
			-- These write the bare path DIRECTLY, bypassing any such flow entirely: an out-of-range `active`
			-- must be rejected and rolled back here, because the very next StateSyncServerStore.sync would otherwise
			-- index `profile.slots[active]` (nil) inside the locked commit region.
			describe("data-layer validation", function()
				local function expectRejected(newActive: any)
					local ok = PlayerDataService:mutate(USER_ID, "slotState", function(slotState: any)
						slotState.active = newActive
						return true
					end)
					expect(ok).to.equal(false)
					-- Rolled back: the stored value is untouched, so getActiveSlot still resolves a real slot.
					expect(PlayerDataService:getActiveSlot(USER_ID)).to.equal(1)
					-- And the mirror still shows slot 1's currency (the rejected write never reached sync).
					expect((StateSyncServerStore.snapshot("currency")[USER_ID] :: any).coins).to.equal(SLOT_1_COINS)
				end

				itMultiSlot("accepts an in-range slot", function()
					local ok = PlayerDataService:mutate(USER_ID, "slotState", function(slotState: any)
						slotState.active = 2
						return true
					end)
					expect(ok).to.equal(true)
					expect(PlayerDataService:getActiveSlot(USER_ID)).to.equal(2)
				end)

				it("rejects and rolls back an active slot above MAX_SLOTS", function()
					expectRejected(PlayerDataConstants.MAX_SLOTS + 1)
				end)

				it("rejects and rolls back a zero active slot", function()
					expectRejected(0)
				end)

				it("rejects and rolls back a fractional active slot", function()
					expectRejected(2.5)
				end)

				it("rejects and rolls back a non-number active slot", function()
					expectRejected("2")
				end)

				-- The epoch guards transaction()'s stale-op check, so the data layer rejects a shape that would
				-- make that comparison meaningless — through mutate() as well as a raw transaction op.
				it("rejects a non-integer epoch", function()
					local ok = PlayerDataService:mutate(USER_ID, "slotState", function(slotState: any)
						slotState.epoch = 2.5
						return true
					end)
					expect(ok).to.equal(false)
					expect(PlayerDataService:getSlotEpoch(USER_ID)).to.equal(1)
				end)

				it("rejects an epoch below 1", function()
					local ok = PlayerDataService:mutate(USER_ID, "slotState", function(slotState: any)
						slotState.epoch = 0
						return true
					end)
					expect(ok).to.equal(false)
					expect(PlayerDataService:getSlotEpoch(USER_ID)).to.equal(1)
				end)

				itMultiSlot("accepts a bumped epoch", function()
					local ok = PlayerDataService:mutate(USER_ID, "slotState", function(slotState: any)
						slotState.active = 2
						slotState.epoch += 1
						return true
					end)
					expect(ok).to.equal(true)
					expect(PlayerDataService:getSlotEpoch(USER_ID)).to.equal(2)
				end)

				it("rejects an out-of-range active slot written through a raw transaction op", function()
					local ok = PlayerDataService:transaction({
						{
							userId = USER_ID,
							path = "slotState",
							mutator = function(slotState: any)
								slotState.active = 4
								return true
							end,
						},
					})
					expect(ok).to.equal(false)
					expect(PlayerDataService:getActiveSlot(USER_ID)).to.equal(1)
				end)
			end)
		end)

		describe("transaction", function()
			it("commits all operations for a single user", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins -= 100
							return true
						end,
					},
					{
						userId = 1,
						path = INVENTORY_PATH,
						mutator = function(inv: any)
							-- "wrench" is a tool with no stackMax (unique, not stackable) so it needs a uid.
							table.insert(inv.items, { itemType = "wrench", uid = "tx-1" })
							return true
						end,
					},
				})
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).currency.coins).to.equal(0)
				expect(#activeSlotOf(profile).inventory.items).to.equal(1)
			end)

			it("commits a trade built from typed service ops (currencyOp / inventoryOp)", function()
				-- End-to-end: ops minted by the owning services run through the REAL transaction()
				-- against seeded profiles. This is the typed alternative to raw operation tables.
				local seller = seed(1, 0)
				local buyer = seed(2, 500)
				table.insert(activeSlotOf(seller).inventory.items, { itemType = "wrench", uid = "w-1" })

				local ok = PlayerDataService:transaction({
					InventoryService:inventoryOp(1, function(inv)
						table.remove(inv.items, 1)
						return true
					end),
					CurrencyService:currencyOp(1, function(c)
						c.coins += 500
						return true
					end),
					InventoryService:inventoryOp(2, function(inv)
						table.insert(inv.items, { itemType = "wrench", uid = "w-1" })
						return true
					end),
					CurrencyService:currencyOp(2, function(c)
						if c.coins < 500 then
							return false
						end
						c.coins -= 500
						return true
					end),
				})

				expect(ok).to.equal(true)
				expect(activeSlotOf(seller).currency.coins).to.equal(500)
				expect(#activeSlotOf(seller).inventory.items).to.equal(0)
				expect(activeSlotOf(buyer).currency.coins).to.equal(0)
				expect(activeSlotOf(buyer).inventory.items[1].itemType).to.equal("wrench")
			end)

			it("commits a multi-user trade atomically", function()
				local seller = seed(1, 0)
				local buyer = seed(2, 500)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins += 500
							return true
						end,
					},
					{
						userId = 2,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins -= 500
							return true
						end,
					},
				})
				expect(ok).to.equal(true)
				expect(activeSlotOf(seller).currency.coins).to.equal(500)
				expect(activeSlotOf(buyer).currency.coins).to.equal(0)
			end)

			it(
				"mirrors only the touched (userId, path) pairs into StateSyncServerStore, not every affected profile in full (A2)",
				function()
					seed(1, 0)
					seed(2, 500)
					StateSyncServerStore.setInventory(1, { { itemType = "shield", quantity = 1 } })
					StateSyncServerStore.setInventory(2, { { itemType = "helm", quantity = 1 } })
					local seller1InventoryBefore = StateSyncServerStore.inventories()[1]
					local buyer2InventoryBefore = StateSyncServerStore.inventories()[2]

					PlayerDataService:transaction({
						{
							userId = 1,
							path = CURRENCY_PATH,
							mutator = function(c: any)
								c.coins += 500
								return true
							end,
						},
						{
							userId = 2,
							path = CURRENCY_PATH,
							mutator = function(c: any)
								c.coins -= 500
								return true
							end,
						},
					})

					expect(StateSyncServerStore.currencies()[1].coins).to.equal(500)
					expect(StateSyncServerStore.currencies()[2].coins).to.equal(0)
					-- Neither op touched "inventory" for either user, so both stay untouched.
					expect(StateSyncServerStore.inventories()[1]).to.equal(seller1InventoryBefore)
					expect(StateSyncServerStore.inventories()[2]).to.equal(buyer2InventoryBefore)
				end
			)

			it("rolls back ALL users when a later mutator returns false", function()
				local a = seed(1, 100)
				local b = seed(2, 50)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							return true
						end,
					},
					{
						userId = 2,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							return false -- abort the whole transaction
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(activeSlotOf(a).currency.coins).to.equal(100)
				expect(activeSlotOf(b).currency.coins).to.equal(50)
			end)

			it("rolls back when a mutator errors", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							return true
						end,
					},
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function()
							error("boom")
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("rolls back when a mutator yields", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							task.wait() -- contract violation: mutators must be synchronous
							c.coins = 0
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("returns false and leaves data untouched when a profile is not loaded", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							return true
						end,
					},
					{
						userId = 999, -- not loaded
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("does NOT leave a profile locked after a not-loaded bail (regression)", function()
				local profile = seed(1, 100)
				-- Bails in validation because user 999 isn't loaded.
				PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function()
							return true
						end,
					},
					{
						userId = 999,
						path = CURRENCY_PATH,
						mutator = function()
							return true
						end,
					},
				})
				-- User 1 must still be mutable — it was never locked.
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 7
					return true
				end)
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).currency.coins).to.equal(7)
			end)

			it("locks the profile against re-entrant mutate() during the transaction", function()
				local profile = seed(1, 100)
				local nestedResult: boolean? = nil
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							-- The profile is locked for the lifetime of the transaction,
							-- so a nested mutate() on the same profile must be refused.
							nestedResult = PlayerDataService:mutate(1, CURRENCY_PATH, function(cc: any)
								cc.coins = 999
								return true
							end)
							c.coins = 5
							return true
						end,
					},
				})
				expect(ok).to.equal(true)
				expect(nestedResult).to.equal(false)
				expect(activeSlotOf(profile).currency.coins).to.equal(5)
			end)

			it("returns true for an empty operations list", function()
				expect(PlayerDataService:transaction({})).to.equal(true)
			end)

			it("rejects a malformed op in side-effect-free Phase 1, leaving no lock behind (regression)", function()
				local profile = seed(1, 100)
				-- Every op-shape error (non-function mutator, non-string path, non-number userId) is a
				-- dev error and must assert BEFORE any profile is locked. If this validation ever moved
				-- past Phase 2, the throw would skip clearTransactionFlags and permanently lock the
				-- profile (until server restart).
				local malformedOps: { any } = {
					{ userId = 1, path = CURRENCY_PATH, mutator = "not a function" },
					{
						userId = 1,
						path = 123,
						mutator = function()
							return true
						end,
					},
					{
						userId = "bad",
						path = CURRENCY_PATH,
						mutator = function()
							return true
						end,
					},
				}
				for _, badOp in malformedOps do
					expect(function()
						PlayerDataService:transaction({ badOp })
					end).to.throw()
				end
				-- The profile was never locked — it must still be mutable.
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 7
					return true
				end)
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).currency.coins).to.equal(7)
			end)

			it("keeps a user mutable on rejoin after a mid-transaction session teardown", function()
				-- Integration guard for the _cleanupPlayer transaction-lock sweep: ending the session
				-- mid-transaction drops it from the session table, and a later rejoin must not be
				-- refused by a stale lock. (In production clearTransactionFlags also clears the lock at
				-- transaction end, so this exercises the teardown+rejoin path rather than isolating the
				-- sweep line, which is belt-and-braces for an otherwise-unreachable lock leak.)
				seed(1, 100)
				local sessionGoneDuring: boolean? = nil
				PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							PlayerDataService:_cleanupPlayer(1)
							sessionGoneDuring = PlayerDataService:getState().sessions["1"] == nil
							c.coins = 1
							return true
						end,
					},
				})
				expect(sessionGoneDuring).to.equal(true)
				-- Re-seed the same userId (a rejoin): the session must accept mutations again.
				local profile = seed(1, 50)
				local ok = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 9
					return true
				end)
				expect(ok).to.equal(true)
				expect(activeSlotOf(profile).currency.coins).to.equal(9)
			end)

			it(
				"does NOT re-mirror a profile removed before the commit's mirror pass (zombie entry regression)",
				function()
					seed(1, 100)
					-- A departed player is dropped from StateSyncServerStore by _cleanupPlayer. If the post-commit
					-- mirror loop then re-synced their slice, it would leave a stale atom entry for a gone
					-- session that nothing ever removes again. Simulate the departure inside the mutator
					-- (the same code path the persist-backoff-then-leave window hits) and assert the mirror
					-- pass skips the removed user.
					PlayerDataService:transaction({
						{
							userId = 1,
							path = CURRENCY_PATH,
							mutator = function(c: any)
								c.coins = 1
								PlayerDataService:_cleanupPlayer(1) -- player leaves mid-commit
								return true
							end,
						},
					})
					-- The removed user must NOT have been re-inserted into the reactive mirror.
					expect(StateSyncServerStore.currencies()[1]).to.equal(nil)
				end
			)

			it("reports persisted = false for an empty { persist = true } transaction (no save ran)", function()
				local ok, result = PlayerDataService:transaction({}, { persist = true })
				expect(ok).to.equal(true)
				expect(result.committed).to.equal(true)
				-- Nothing was saved, so "durably persisted" would be a vacuous lie.
				expect(result.persisted).to.equal(false)
				expect(#result.failedUserIds).to.equal(0)
			end)

			it("fails atomically when an operation references a nonexistent path", function()
				local profile = seed(1, 100)
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							return true
						end,
					},
					{
						userId = 1,
						path = "quests", -- not in the profile template
						mutator = function(q: any)
							q.active = "dragon-hunt"
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(result.committed).to.equal(false)
				-- Refused in side-effect-free validation: nothing was applied...
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
				-- ...no key was created for the missing path (the rollback snapshot cannot
				-- represent "path absent", so creation must be refused up front)...
				expect(profile.Data.quests).to.equal(nil)
				-- ...and the profile was never locked.
				local mutateOk = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 7
					return true
				end)
				expect(mutateOk).to.equal(true)
			end)

			it("refuses (does not throw) an op whose path is empty", function()
				seed(1, 100)
				local ok, result
				expect(function()
					ok, result = PlayerDataService:transaction({
						{
							userId = 1,
							path = "",
							mutator = function()
								return true
							end,
						},
					})
				end).never.to.throw()
				expect(ok).to.equal(false)
				expect(result.committed).to.equal(false)
				-- Never locked: a follow-up mutate for the same user still works.
				local mutateOk = PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 7
					return true
				end)
				expect(mutateOk).to.equal(true)
			end)

			it("rolls back ALL users when an auto-save fires mid-transaction (OnSave abort)", function()
				local a = seed(1, 100)
				local b = seed(2, 50)
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							return true
						end,
					},
					{
						userId = 2,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							-- Simulate ProfileStore auto-saving this profile mid-transaction. The seam
							-- wires the same OnSave abort handler as a live session, so this flips the
							-- abort flag; the post-mutator check must then roll back EVERY affected
							-- profile from its snapshot, not just this one.
							b.OnSave:Fire()
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(result.committed).to.equal(false)
				expect(activeSlotOf(a).currency.coins).to.equal(100)
				expect(activeSlotOf(b).currency.coins).to.equal(50)
				-- The abort path released both locks — the profiles are mutable again.
				expect(PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 1
					return true
				end)).to.equal(true)
			end)

			it("commits in memory without forcing a save by default (persisted = false)", function()
				local profile = seedProfile(1, makeFakeProfile(makeSlotData(100)))
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 50
							return true
						end,
					},
				})
				expect(ok).to.equal(true)
				expect(result.committed).to.equal(true)
				-- Default: committed in memory only, not durably saved this call.
				expect(result.persisted).to.equal(false)
				expect(#result.failedUserIds).to.equal(0)
				-- The mutation is applied in memory...
				expect(activeSlotOf(profile).currency.coins).to.equal(50)
				-- ...but no forced save was performed (the whole point of #5).
				expect(profile:_getSaveCalls()).to.equal(0)
			end)

			it("reports persisted = true when { persist = true } and the save succeeds", function()
				local profile = seedProfile(1, makeFakeProfile(makeSlotData(100)))
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 50
							return true
						end,
					},
				}, { persist = true })
				expect(ok).to.equal(true)
				expect(result.committed).to.equal(true)
				expect(result.persisted).to.equal(true)
				expect(#result.failedUserIds).to.equal(0)
				-- persist = true forces exactly one successful save.
				expect(profile:_getSaveCalls()).to.equal(1)
			end)

			it("refuses a nested transaction on a profile already in a transaction", function()
				local profile = seed(1, 100)
				local nestedOk: boolean? = nil
				local nestedResult: any = nil
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							-- The profile is locked for the outer transaction; re-entering it must be refused
							-- so the nested commit can't wipe the outer transaction's lock state.
							nestedOk, nestedResult = PlayerDataService:transaction({
								{
									userId = 1,
									path = CURRENCY_PATH,
									mutator = function(cc: any)
										cc.coins = 999
										return true
									end,
								},
							})
							c.coins = 5
							return true
						end,
					},
				})
				expect(ok).to.equal(true)
				expect(nestedOk).to.equal(false)
				expect(nestedResult.committed).to.equal(false)
				-- Only the outer mutation applied; the refused nested call changed nothing.
				expect(activeSlotOf(profile).currency.coins).to.equal(5)
			end)

			it("rolls back and fails when a profile is inactive at the commit gate", function()
				-- Inactive from the first IsActive() call — which is now the pre-commit atomicity gate,
				-- since Phase 2 no longer force-saves (and so no longer probes IsActive first).
				local profile = seedProfile(1, makeFakeProfile(makeSlotData(100), { activeUntilCall = 0 }))
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(result.committed).to.equal(false)
				-- Rolled back from the in-memory snapshot: the original value is restored.
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("commits in memory but reports failedUserIds when a persist save keeps failing", function()
				-- persist = true forces a save that throws on every attempt (saveFailFrom = 1), so the
				-- transaction commits in memory yet cannot be persisted this server.
				local profile = seedProfile(1, makeFakeProfile(makeSlotData(100), { saveFailFrom = 1 }))
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 40
							return true
						end,
					},
				}, { persist = true })
				expect(ok).to.equal(true)
				expect(result.committed).to.equal(true)
				expect(result.persisted).to.equal(false)
				expect(#result.failedUserIds).to.equal(1)
				expect(result.failedUserIds[1]).to.equal(1)
				-- The mutation is present in memory even though the durable save failed.
				expect(activeSlotOf(profile).currency.coins).to.equal(40)
			end)

			it("treats a dispatched-but-unconfirmed save as not persisted (no OnAfterSave)", function()
				-- ProfileStore's Save() only dispatches the write; durability is confirmed by
				-- OnAfterSave. A save that returns cleanly but is never confirmed must NOT report
				-- persisted = true — that was the old behavior (pcall success == "saved").
				local profile = seedProfile(1, makeFakeProfile(makeSlotData(100), { suppressAfterSave = true }))
				PlayerDataService:_setPersistConfirmTimeoutForTesting(0.05)
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 40
							return true
						end,
					},
				}, { persist = true })
				PlayerDataService:_setPersistConfirmTimeoutForTesting(nil)
				expect(ok).to.equal(true)
				expect(result.committed).to.equal(true)
				expect(result.persisted).to.equal(false)
				expect(#result.failedUserIds).to.equal(1)
				expect(result.failedUserIds[1]).to.equal(1)
				-- Every attempt dispatched a save; none was ever confirmed.
				expect(profile:_getSaveCalls()).to.equal(3)
				-- The commit itself stands (in memory; the normal auto-save retries the write).
				expect(activeSlotOf(profile).currency.coins).to.equal(40)
			end)

			it("rolls back a scalar-path operation without leaking the transaction lock", function()
				-- _schemaVersion is a scalar profile path: it passes Phase 1's existence check, so
				-- Phase 2 must snapshot it WITHOUT sift.Dictionary.copyDeep (which throws on a
				-- non-table). The old code threw there with the lock already taken, permanently
				-- refusing this user's mutate()/transaction() until they left (lock-leak regression).
				-- `_schemaVersion` is the profile's one ROOT-LEVEL scalar — a bare key, not a dotted
				-- slice path (an arbitrary stored version, so the rollback assertion is unambiguous).
				local data = makeSlotData(100)
				data._schemaVersion = 3
				local profile = seedProfile(1, makeFakeProfile(data))
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							return true
						end,
					},
					{
						userId = 1,
						path = "_schemaVersion",
						mutator = function()
							return false -- abort: the whole transaction must roll back
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(result.committed).to.equal(false)
				-- Rolled back, scalar path included.
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
				expect(profile.Data._schemaVersion).to.equal(3)
				-- And crucially: the lock was released, not leaked.
				expect(PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 7
					return true
				end)).to.equal(true)
			end)

			it("commits a transaction that touches a scalar path (snapshot stays total)", function()
				-- The committing twin of the rollback test above: a dotted slice path (which mirrors)
				-- alongside the root-level `_schemaVersion` scalar (which does not).
				local data = makeSlotData(100)
				data._schemaVersion = 3
				local profile = seedProfile(1, makeFakeProfile(data))
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 55
							return true
						end,
					},
					{
						userId = 1,
						path = "_schemaVersion",
						mutator = function()
							return true -- scalar values can't be mutated in place; a read-only op is fine
						end,
					},
				})
				expect(ok).to.equal(true)
				expect(result.committed).to.equal(true)
				expect(activeSlotOf(profile).currency.coins).to.equal(55)
				expect(profile.Data._schemaVersion).to.equal(3)
			end)

			it("writes a TRANSACTION_COMMIT audit entry for each affected user", function()
				-- Transactions are the economy-critical path (trades): a committed one must land in
				-- the audit trail, not just the debug channel. The suite runs at level NONE, so
				-- raise to AUDIT just for this assertion.
				seed(1, 100)
				seed(2, 50)
				Logger.setGlobalLevel("AUDIT")
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 90
							return true
						end,
					},
					{
						userId = 2,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 60
							return true
						end,
					},
				})
				Logger.setGlobalLevel("NONE")
				expect(ok).to.equal(true)
				local audited: { [string]: boolean } = {}
				for _, entry in Logger.getHistory() do
					if
						entry.level == "AUDIT"
						and entry.context == "PlayerDataServiceServer"
						and string.find(entry.message, "TRANSACTION_COMMIT", 1, true)
					then
						for userId in string.gmatch(entry.message, "userId=(%d+)") do
							audited[userId] = true
						end
					end
				end
				expect(audited["1"]).to.equal(true)
				expect(audited["2"]).to.equal(true)
			end)

			-- =================================================================
			-- The stale-op guard: an op minted for a SLOT slice bakes one concrete slot into its path,
			-- so an op held across a yield (a trade awaiting the other side's confirmation) can outlive
			-- the character it was minted for. transaction() REFUSES such an op rather than committing
			-- it against the abandoned character (where the mirror gate would also hide it from the
			-- client). It must refuse in the side-effect-free validation phase — no lock, no mutator,
			-- no mirror — which is what the isInTransaction assertions below pin down.
			describe("stale op rejection (slot epoch)", function()
				it("commits an op minted under the CURRENT epoch", function()
					local profile = seed(1, 100)
					local op = CurrencyService:currencyOp(1, function(currency)
						currency.coins += 10
						return true
					end)
					expect(op.epoch).to.equal(profile.Data.slotState.epoch)

					local committed = PlayerDataService:transaction({ op })
					expect(committed).to.equal(true)
					expect(activeSlotOf(profile).currency.coins).to.equal(110)
				end)

				itMultiSlot("REJECTS an op minted before a slot switch, and writes NOTHING", function()
					local profile = seed(1, 250)
					local coinsBefore = activeSlotOf(profile).currency.coins

					-- Mint against slot 1 (the trade begins)...
					local op = CurrencyService:currencyOp(1, function(currency)
						currency.coins += 1000
						return true
					end)

					-- ...the player switches character mid-trade (this is the yield window)...
					local switched = PlayerDataService:mutate(1, "slotState", function(slotState: any)
						slotState.active = 2
						slotState.epoch += 1
						return true
					end)
					expect(switched).to.equal(true)

					-- ...and the trade tries to commit. It must be REFUSED, not rerouted.
					local committed = PlayerDataService:transaction({ op })
					expect(committed).to.equal(false)

					-- The abandoned character (slot 1) must be untouched — that is the whole point.
					expect(profile.Data.slots[1].currency.coins).to.equal(coinsBefore)
					-- And the new character must not have received it either (still the template default).
					expect(profile.Data.slots[2].currency.coins).to.equal(100)
					-- Refused BEFORE any lock was taken, so none can have leaked.
					expect(PlayerDataService:isInTransaction(1)).to.equal(false)
				end)

				it("rejects the WHOLE transaction when one op is stale", function()
					-- A trade is atomic by definition: committing the leg whose epoch still matches would
					-- be worse than committing nothing.
					local profile = seed(1, 100)
					local freshOp = CurrencyService:currencyOp(1, function(currency)
						currency.coins += 5
						return true
					end)
					local staleOp = CurrencyService:currencyOp(1, function(currency)
						currency.coins += 5
						return true
					end)
					staleOp.epoch = 999 -- simulate an op minted under a long-gone epoch

					local committed = PlayerDataService:transaction({ freshOp, staleOp })
					expect(committed).to.equal(false)
					-- The fresh op's mutator must not have run either.
					expect(activeSlotOf(profile).currency.coins).to.equal(100)
					expect(PlayerDataService:isInTransaction(1)).to.equal(false)
				end)

				itMultiSlot("does NOT epoch-check an ACCOUNT op (a switch cannot invalidate account data)", function()
					local profile = seed(1, 100)
					-- The shape PlayerDataSliceSystem.registerAccount's `op` mints: the account path and NO
					-- epoch stamp (account data is slot-independent).
					local op = {
						userId = 1,
						path = ITEM_MINT_PATH,
						mutator = function(mint: any)
							mint.nextUid += 1
							return true
						end,
					}

					PlayerDataService:mutate(1, "slotState", function(slotState: any)
						slotState.active = 2
						slotState.epoch += 1
						return true
					end)

					-- Minted before the switch, but account-scoped, so it still commits.
					expect(PlayerDataService:transaction({ op })).to.equal(true)
					expect(profile.Data.account.itemMint.nextUid).to.equal(2)
				end)

				it("does not epoch-check a RAW op table (it carries no epoch)", function()
					-- Raw hand-built ops are unchecked by construction: nothing stamps an epoch onto them.
					-- The typed builders are the safe path — this documents the gap rather than hiding it.
					local profile = seed(1, 100)
					local op = {
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins += 1
							return true
						end,
					}
					PlayerDataService:mutate(1, "slotState", function(slotState: any)
						slotState.epoch += 1
						return true
					end)
					expect(PlayerDataService:transaction({ op })).to.equal(true)
					expect(activeSlotOf(profile).currency.coins).to.equal(101)
				end)
			end)
		end)

		-- =====================================================================
		describe("session lifecycle (_startSession)", function()
			-- Installs a fake PlayerStore whose StartSessionAsync returns `profile` (or errors with
			-- `storeError`). Returns a getter for the profile key the service requested.
			local function installStore(profile: any?, storeError: string?): () -> string?
				local capturedKey: string? = nil
				PlayerDataService.PlayerStore = {
					StartSessionAsync = function(_self, key: string)
						capturedKey = key
						if storeError then
							error(storeError)
						end
						return profile
					end,
				} :: any
				return function()
					return capturedKey
				end
			end

			afterEach(function()
				-- _cleanupPlayer is safe to call repeatedly; sweep every userId these tests use so
				-- sessions, janitors, and the StateSyncServerStore mirror never leak across specs.
				PlayerDataService:_cleanupPlayer(1)
				PlayerDataService:_cleanupPlayer(2)
				PlayerDataService.PlayerStore = nil
			end)

			it("loads, migrates, registers, and seeds the reactive mirror on a successful join", function()
				-- A PRE-VERSIONING profile: the stored data carries no _schemaVersion at all (the
				-- fixture stamps one, so drop it), which is the case the migration path must treat as
				-- the v1 baseline.
				local data = makeSlotData(100)
				data._schemaVersion = nil
				local profile = makeFakeSessionProfile(data)
				local getKey = installStore(profile)
				local host = makeFakeHost(1)
				PlayerDataService:_startSession(host)

				expect(getKey()).to.equal("1")
				expect(#host._kicks).to.equal(0)
				expect(profile:_getAddedUserIds()[1]).to.equal(1)
				-- A pre-versioning profile (no _schemaVersion) is treated as the v1 baseline and
				-- stamped current — the stored version was read BEFORE Reconcile backfilled it.
				expect(profile.Data._schemaVersion).to.equal(PlayerDataMigrationSystem.CURRENT_VERSION)
				expect(PlayerDataService:getState().sessions["1"]).to.be.ok()
				-- The reactive projection is seeded at load, no separate handshake.
				expect(StateSyncServerStore.currencies()[1].coins).to.equal(100)
				-- And the session accepts writes.
				expect(PlayerDataService:mutate(1, CURRENCY_PATH, function(c: any)
					c.coins = 1
					return true
				end)).to.equal(true)
			end)

			-- Found in staging: a body can spawn before its profile loads (a same-server rejoin waits on the
			-- previous session's lock), so systems that publish from the profile need to hear when it arrives.
			it("fires profileLoaded with the userId after a successful join, and not on a failed load", function()
				local fired: { number } = {}
				local connection = PlayerDataService.profileLoaded:Connect(function(userId: number)
					table.insert(fired, userId)
				end)
				installStore(makeFakeSessionProfile(makeSlotData(100)))
				PlayerDataService:_startSession(makeFakeHost(1))
				installStore(nil, "simulated datastore outage")
				PlayerDataService:_startSession(makeFakeHost(2))
				task.wait() -- SignalPlus delivers on task.defer
				connection:Disconnect()
				expect(#fired).to.equal(1)
				expect(fired[1]).to.equal(1)
			end)

			it("kicks and registers nothing when the profile load errors", function()
				installStore(nil, "simulated datastore outage")
				local host = makeFakeHost(1)
				PlayerDataService:_startSession(host)

				expect(host._kicks[1]).to.equal("Profile load error - Please rejoin")
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
				expect(StateSyncServerStore.currencies()[1]).to.equal(nil)
			end)

			it("kicks when the store returns no profile (server shutting down)", function()
				installStore(nil)
				local host = makeFakeHost(1)
				PlayerDataService:_startSession(host)

				expect(host._kicks[1]).to.equal("Profile load fail - Please rejoin")
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
			end)

			it("refuses a profile written by a newer server (too_new) and leaves its data pristine", function()
				local data = makeSlotData(100)
				data._schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION + 1
				local profile = makeFakeSessionProfile(data)
				local host = makeFakeHost(1)
				installStore(profile)
				PlayerDataService:_startSession(host)

				expect(host._kicks[1]).to.equal("This server is updating - please rejoin")
				expect(profile:_wasSessionEnded()).to.equal(true)
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
				-- The newer data was restored from LastSavedData exactly as loaded — never
				-- migrated, never stamped down.
				expect(profile.Data._schemaVersion).to.equal(PlayerDataMigrationSystem.CURRENT_VERSION + 1)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("kicks and leaves data untouched when a migration fails", function()
				local data = makeSlotData(100)
				-- Below the v1 baseline: apply() walks to a missing migration entry and reports
				-- "failed" — the same outcome as a registered migration that errors.
				data._schemaVersion = 0
				local profile = makeFakeSessionProfile(data)
				local host = makeFakeHost(1)
				installStore(profile)
				PlayerDataService:_startSession(host)

				expect(host._kicks[1]).to.equal("Profile migration error - Please rejoin")
				expect(profile:_wasSessionEnded()).to.equal(true)
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
				-- Rolled back to exactly what was loaded, so nothing half-migrated can persist.
				expect(profile.Data._schemaVersion).to.equal(0)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)

			it("ends the session quietly when the player left during load", function()
				local profile = makeFakeSessionProfile(makeSlotData(100))
				local host = makeFakeHost(1)
				host._setPresent(false)
				installStore(profile)
				PlayerDataService:_startSession(host)

				expect(profile:_wasSessionEnded()).to.equal(true)
				expect(#host._kicks).to.equal(0)
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
				expect(StateSyncServerStore.currencies()[1]).to.equal(nil)
			end)

			it("cleans up and kicks when the session ends externally (OnSessionEnd)", function()
				local profile = makeFakeSessionProfile(makeSlotData(100))
				local host = makeFakeHost(1)
				installStore(profile)
				PlayerDataService:_startSession(host)
				expect(PlayerDataService:getState().sessions["1"]).to.be.ok()

				profile.OnSessionEnd:Fire()

				expect(host._kicks[1]).to.equal("Profile session end - Please rejoin")
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
				-- The reactive mirror is swept with the session.
				expect(StateSyncServerStore.currencies()[1]).to.equal(nil)
			end)

			it("wires the live OnSave abort handler: an auto-save mid-transaction rolls back", function()
				-- The seam-based OnSave tests above exercise the abort machinery through
				-- _setProfileForTesting's connection; this proves a REAL join wires the same
				-- handler through the session janitor.
				local profile = makeFakeSessionProfile(makeSlotData(100))
				local host = makeFakeHost(1)
				installStore(profile)
				PlayerDataService:_startSession(host)

				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = CURRENCY_PATH,
						mutator = function(c: any)
							c.coins = 0
							profile.OnSave:Fire() -- simulated auto-save mid-transaction
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(activeSlotOf(profile).currency.coins).to.equal(100)
			end)
		end)

		-- =====================================================================
		describe("isInTransaction", function()
			local USER_ID = 1

			beforeEach(function()
				seed(USER_ID, 100)
			end)

			it("is false for a loaded profile with no transaction running", function()
				expect(PlayerDataService:isInTransaction(USER_ID)).to.equal(false)
			end)

			it("is false for a userId with no profile", function()
				expect(PlayerDataService:isInTransaction(999)).to.equal(false)
			end)

			it("is true while a transaction is mid-flight for that user", function()
				local observed = nil
				PlayerDataService:transaction({
					{
						userId = USER_ID,
						path = CURRENCY_PATH,
						mutator = function(currency: any)
							-- Observed from INSIDE the locked region: this is exactly the state a slot
							-- switch must refuse on.
							observed = PlayerDataService:isInTransaction(USER_ID)
							currency.coins += 1
							return true
						end,
					},
				})
				expect(observed).to.equal(true)
			end)

			it("is false again after the transaction commits", function()
				PlayerDataService:transaction({
					{
						userId = USER_ID,
						path = CURRENCY_PATH,
						mutator = function(currency: any)
							currency.coins += 1
							return true
						end,
					},
				})
				expect(PlayerDataService:isInTransaction(USER_ID)).to.equal(false)
			end)
		end)
	end)
end
