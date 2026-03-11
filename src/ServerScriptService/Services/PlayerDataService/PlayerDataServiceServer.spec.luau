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

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)
local PlayerDataMigrations = require(ServerScriptService.Modules.PlayerDataMigrations)
local CurrencyService = require(ServerScriptService.Services.CurrencyService.CurrencyServiceServer)
local InventoryService = require(ServerScriptService.Services.InventoryService.InventoryServiceServer)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local sift = require(ReplicatedStorage.Packages.sift)
local ServerStore = require(ServerScriptService.State.ServerStore)

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

local function makeData(gold: number)
	return { currency = { gold = gold, gems = 0 }, inventory = {} }
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
			self.Data._schemaVersion = PlayerDataMigrations.CURRENT_VERSION
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
			-- Clear seeded profiles from the real registry, and their ServerStore mirror, so
			-- specs stay isolated (mutate()/transaction() write into ServerStore as a side effect).
			for userId in profiles do
				PlayerDataService:_setProfileForTesting(userId, nil)
				ServerStore.remove(userId)
			end
			profiles = {}
		end)

		local function seed(userId: number, gold: number)
			local profile = makeFakeProfile(makeData(gold))
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

		-- =====================================================================
		describe("mutate", function()
			it("applies the mutation and returns true", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 250
					return true
				end)
				expect(ok).to.equal(true)
				expect(profile.Data.currency.gold).to.equal(250)
			end)

			it("mirrors only the mutated slice into ServerStore, not every synced slice (A2)", function()
				seed(1, 100)
				ServerStore.setInventory(1, { { itemType = "shield", quantity = 1 } })
				local inventoryBefore = ServerStore.inventories()

				PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 250
					return true
				end)

				expect(ServerStore.currencies()[1].gold).to.equal(250)
				-- Mutating "currency" must not touch the inventory atom at all.
				expect(ServerStore.inventories()).to.equal(inventoryBefore)
			end)

			it("rolls back writes when the mutator reports no change (false = no change is ENFORCED)", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 999 -- writes, then aborts
					return false
				end)
				expect(ok).to.equal(false)
				-- The write is rolled back from the pre-mutate snapshot, so the returned flag and
				-- the stored state agree — the dirty 999 can never ride the next auto-save.
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("rejects a mutator that yields and leaves the slice untouched", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					task.wait() -- contract violation: mutators must be synchronous
					c.gold = 999
					return true
				end)
				expect(ok).to.equal(false)
				-- Rejected before the write, so the slice is untouched and never mirrored.
				expect(profile.Data.currency.gold).to.equal(100)
				expect(ServerStore.currencies()[1]).to.equal(nil)
			end)

			it("rolls back a mutator that writes and THEN yields (regression)", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 999 -- the write lands before the contract violation...
					task.wait()
					return true
				end)
				expect(ok).to.equal(false)
				-- ...and must be restored from the snapshot, not left to persist via auto-save.
				expect(profile.Data.currency.gold).to.equal(100)
				expect(ServerStore.currencies()[1]).to.equal(nil)
			end)

			it("rejects a mutator that errors without crashing the caller", function()
				local profile = seed(1, 100)
				local ok: boolean? = nil
				expect(function()
					ok = PlayerDataService:mutate(1, "currency", function()
						error("boom")
					end)
				end).never.to.throw()
				expect(ok).to.equal(false)
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("rolls back a mutator that writes and THEN errors (regression)", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 999
					error("boom after writing")
				end)
				expect(ok).to.equal(false)
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("returns false when the profile is not loaded", function()
				expect(PlayerDataService:mutate(404, "currency", function()
					return true
				end)).to.equal(false)
			end)

			it("returns false when the path does not exist", function()
				seed(1, 100)
				expect(PlayerDataService:mutate(1, "quests", function()
					return true
				end)).to.equal(false)
			end)

			it("throws for a non-number userId", function()
				expect(function()
					PlayerDataService:mutate("bad" :: any, "currency", function()
						return true
					end)
				end).to.throw()
			end)

			it("refuses a write to a profile whose session is no longer active", function()
				-- activeUntilCall = 0 makes IsActive() return false on its first call — the state a
				-- profile is in after its session ended but before _cleanupPlayer removed the entry.
				local profile = seedProfile(1, makeFakeProfile(makeData(100), { activeUntilCall = 0 }))
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 250
					return true
				end)
				expect(ok).to.equal(false)
				-- No doomed write, and nothing mirrored to the client.
				expect(profile.Data.currency.gold).to.equal(100)
				expect(ServerStore.currencies()[1]).to.equal(nil)
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
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = -5
					return true
				end)
				expect(ok).to.equal(false)
				expect(profile.Data.currency.gold).to.equal(100)
				expect(ServerStore.currencies()[1]).to.equal(nil)
			end)

			it("mutate rolls back a currency write above MAX_CURRENCY", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 2_000_000_000 -- MAX_CURRENCY is 1e9
					return true
				end)
				expect(ok).to.equal(false)
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("transaction rolls the WHOLE txn back when a raw op breaches the currency cap", function()
				local profile = seed(1, 100)
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = -1 -- a hand-built op bypassing removeCurrency's floor
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(result.committed).to.equal(false)
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("transaction rolls back a raw op that exceeds MAX_INVENTORY_SIZE", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "inventory",
						mutator = function(inv: any)
							for _ = 1, InventoryService.MAX_INVENTORY_SIZE + 1 do
								table.insert(inv, { itemType = "iron-sword" })
							end
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				-- The oversized write was rolled back to the empty seeded inventory.
				expect(#profile.Data.inventory).to.equal(0)
			end)

			-- The validators enforce the FULL slice invariant, not just numeric range / size — the
			-- guarantee the owning services document ("holds for ANY path into the slice") must match
			-- what a raw op can actually get past them.
			it("mutate rolls back a write that adds an unregistered currency key", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.dogecoin = 5 -- not in CURRENCIES; must never persist or replicate
					return true
				end)
				expect(ok).to.equal(false)
				expect(profile.Data.currency.dogecoin).to.equal(nil)
				expect(ServerStore.currencies()[1]).to.equal(nil)
			end)

			it("transaction rolls back a raw op that inserts an unregistered itemType", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "inventory",
						mutator = function(inv: any)
							table.insert(inv, { itemType = "not-a-real-item", quantity = 1 })
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(#profile.Data.inventory).to.equal(0)
			end)

			it("transaction rolls back a raw op that writes a non-positive stack quantity", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "inventory",
						mutator = function(inv: any)
							table.insert(inv, { itemType = "iron-sword", quantity = -5 })
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(#profile.Data.inventory).to.equal(0)
			end)

			it("mutate rolls back an inventory write with a non-string instanceId", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, "inventory", function(inv: any)
					table.insert(inv, { itemType = "phoenix-blade", instanceId = 123 })
					return true
				end)
				expect(ok).to.equal(false)
				expect(#profile.Data.inventory).to.equal(0)
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
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					nestedResult = PlayerDataService:mutate(2, "currency", function(c2: any)
						c2.gold = 999
						return true
					end)
					c.gold = 150
					return true
				end)
				-- The nested call is refused and writes nothing; the outer mutation itself is valid
				-- and commits normally.
				expect(nestedResult).to.equal(false)
				expect(other.Data.currency.gold).to.equal(100)
				expect(ok).to.equal(true)
			end)

			it("refuses a nested transaction() from inside a mutate() mutator", function()
				seed(1, 100)
				local other = seed(2, 100)
				local nestedOk: boolean? = nil
				PlayerDataService:mutate(1, "currency", function(c: any)
					nestedOk = PlayerDataService:transaction({
						{
							userId = 2,
							path = "currency",
							mutator = function(c2: any)
								c2.gold = 999
								return true
							end,
						},
					})
					c.gold = 150
					return true
				end)
				expect(nestedOk).to.equal(false)
				expect(other.Data.currency.gold).to.equal(100)
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
						path = "currency",
						mutator = function(c: any)
							escrowPayment = PlayerDataService:mutate(3, "currency", function(c3: any)
								c3.gold += 50
								return true
							end)
							c.gold -= 50
							return true
						end,
					},
					{
						userId = 2,
						path = "currency",
						mutator = function()
							return false -- abort: everything above must unwind
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(result.committed).to.equal(false)
				-- The nested escrow write was refused outright, so nothing survived the rollback.
				expect(escrowPayment).to.equal(false)
				expect(a.Data.currency.gold).to.equal(100)
				expect(b.Data.currency.gold).to.equal(100)
				expect(escrow.Data.currency.gold).to.equal(100)
			end)

			it("clears the guard after every outcome, so subsequent mutations work", function()
				local profile = seed(1, 100)
				-- Rejected outcomes: a yielding mutator and an erroring mutator both pass through the
				-- guarded resume; the flag must never leak set (it would refuse ALL future writes).
				PlayerDataService:mutate(1, "currency", function()
					task.wait()
					return true
				end)
				PlayerDataService:mutate(1, "currency", function()
					error("boom")
				end)
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 123
					return true
				end)
				expect(ok).to.equal(true)
				expect(profile.Data.currency.gold).to.equal(123)
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
						path = "currency",
						mutator = function(c: any)
							observed = PlayerDataService:getState().sessions["1"].inTransaction
							c.gold = 1
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
				table.insert(profile.Data.inventory, { itemType = "iron-sword", quantity = 5 })
				local snap = PlayerDataService:getProfile(1)
				expect(snap).to.be.ok()
				-- A distinct copy, not the live table...
				expect(snap).never.to.equal(profile.Data)
				-- ...and deep-frozen at every level, so an attempt to bypass mutate() by writing to a
				-- nested slice OR an inventory entry throws instead of silently corrupting state.
				expect(table.isfrozen(snap :: any)).to.equal(true)
				expect(function()
					(snap :: any).currency.gold = 1
				end).to.throw()
				expect(function()
					(snap :: any).inventory[1].quantity = 999
				end).to.throw()
				-- The live profile is untouched by the read.
				expect(profile.Data.currency.gold).to.equal(100)
				expect(profile.Data.inventory[1].quantity).to.equal(5)
			end)

			it("returns nil for an unloaded profile", function()
				expect(PlayerDataService:getProfile(404)).to.equal(nil)
			end)
		end)

		-- =====================================================================
		-- The single-slice read path behind SliceOwner.get: getProfile's frozen-copy guarantee at
		-- O(slice) cost. Internal plumbing, but the guarantees are load-bearing (getCurrency /
		-- getInventory read through it), so they are pinned here.
		describe("_getSliceShell", function()
			it("swaps ONLY the requested slice for a frozen deep copy", function()
				local profile = seed(1, 100)
				table.insert(profile.Data.inventory, { itemType = "iron-sword", quantity = 5 })
				local shell = PlayerDataService:_getSliceShell(1, "currency")
				expect(shell).to.be.ok()
				-- The shell is a fresh top-level table, and the requested slice is a distinct,
				-- deep-frozen copy — writing through it throws instead of corrupting live state.
				expect(shell).never.to.equal(profile.Data)
				expect((shell :: any).currency).never.to.equal(profile.Data.currency)
				expect(table.isfrozen((shell :: any).currency)).to.equal(true)
				expect(function()
					(shell :: any).currency.gold = 1
				end).to.throw()
				-- The OTHER slices are intentionally NOT copied — that is what makes this O(slice)
				-- (the shell must be dropped right after the slice is projected out; see the contract).
				expect((shell :: any).inventory).to.equal(profile.Data.inventory)
				-- The live profile is untouched and stays mutable for mutate().
				expect(profile.Data.currency.gold).to.equal(100)
				expect(table.isfrozen(profile.Data.currency)).to.equal(false)
			end)

			it("returns nil for an unloaded profile and for a missing path", function()
				expect(PlayerDataService:_getSliceShell(404, "currency")).to.equal(nil)
				seed(1, 100)
				expect(PlayerDataService:_getSliceShell(1, "quests")).to.equal(nil)
			end)

			it("serves SliceOwner reads end-to-end: getCurrency returns a frozen per-slice snapshot", function()
				local profile = seed(1, 100)
				local currency = CurrencyService:getCurrency(1)
				expect(currency).to.be.ok()
				expect((currency :: any).gold).to.equal(100)
				expect(currency :: any).never.to.equal(profile.Data.currency)
				expect(table.isfrozen(currency :: any)).to.equal(true)
				expect(function()
					(currency :: any).gold = 999
				end).to.throw()
			end)
		end)

		describe("transaction", function()
			it("commits all operations for a single user", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold -= 100
							return true
						end,
					},
					{
						userId = 1,
						path = "inventory",
						mutator = function(inv: any)
							table.insert(inv, { itemType = "iron-sword" })
							return true
						end,
					},
				})
				expect(ok).to.equal(true)
				expect(profile.Data.currency.gold).to.equal(0)
				expect(#profile.Data.inventory).to.equal(1)
			end)

			it("commits a trade built from typed service ops (currencyOp / inventoryOp)", function()
				-- End-to-end: ops minted by the owning services run through the REAL transaction()
				-- against seeded profiles. This is the typed alternative to raw operation tables.
				local seller = seed(1, 0)
				local buyer = seed(2, 500)
				table.insert(seller.Data.inventory, { itemType = "iron-sword", quantity = 1 })

				local ok = PlayerDataService:transaction({
					InventoryService:inventoryOp(1, function(inv)
						table.remove(inv, 1)
						return true
					end),
					CurrencyService:currencyOp(1, function(c)
						c.gold += 500
						return true
					end),
					InventoryService:inventoryOp(2, function(inv)
						table.insert(inv, { itemType = "iron-sword", quantity = 1 })
						return true
					end),
					CurrencyService:currencyOp(2, function(c)
						if c.gold < 500 then
							return false
						end
						c.gold -= 500
						return true
					end),
				})

				expect(ok).to.equal(true)
				expect(seller.Data.currency.gold).to.equal(500)
				expect(#seller.Data.inventory).to.equal(0)
				expect(buyer.Data.currency.gold).to.equal(0)
				expect(buyer.Data.inventory[1].itemType).to.equal("iron-sword")
			end)

			it("commits a multi-user trade atomically", function()
				local seller = seed(1, 0)
				local buyer = seed(2, 500)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold += 500
							return true
						end,
					},
					{
						userId = 2,
						path = "currency",
						mutator = function(c: any)
							c.gold -= 500
							return true
						end,
					},
				})
				expect(ok).to.equal(true)
				expect(seller.Data.currency.gold).to.equal(500)
				expect(buyer.Data.currency.gold).to.equal(0)
			end)

			it(
				"mirrors only the touched (userId, path) pairs into ServerStore, not every affected profile in full (A2)",
				function()
					seed(1, 0)
					seed(2, 500)
					ServerStore.setInventory(1, { { itemType = "shield", quantity = 1 } })
					ServerStore.setInventory(2, { { itemType = "helm", quantity = 1 } })
					local seller1InventoryBefore = ServerStore.inventories()[1]
					local buyer2InventoryBefore = ServerStore.inventories()[2]

					PlayerDataService:transaction({
						{
							userId = 1,
							path = "currency",
							mutator = function(c: any)
								c.gold += 500
								return true
							end,
						},
						{
							userId = 2,
							path = "currency",
							mutator = function(c: any)
								c.gold -= 500
								return true
							end,
						},
					})

					expect(ServerStore.currencies()[1].gold).to.equal(500)
					expect(ServerStore.currencies()[2].gold).to.equal(0)
					-- Neither op touched "inventory" for either user, so both stay untouched.
					expect(ServerStore.inventories()[1]).to.equal(seller1InventoryBefore)
					expect(ServerStore.inventories()[2]).to.equal(buyer2InventoryBefore)
				end
			)

			it("rolls back ALL users when a later mutator returns false", function()
				local a = seed(1, 100)
				local b = seed(2, 50)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
							return true
						end,
					},
					{
						userId = 2,
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
							return false -- abort the whole transaction
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(a.Data.currency.gold).to.equal(100)
				expect(b.Data.currency.gold).to.equal(50)
			end)

			it("rolls back when a mutator errors", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
							return true
						end,
					},
					{
						userId = 1,
						path = "currency",
						mutator = function()
							error("boom")
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("rolls back when a mutator yields", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							task.wait() -- contract violation: mutators must be synchronous
							c.gold = 0
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("returns false and leaves data untouched when a profile is not loaded", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
							return true
						end,
					},
					{
						userId = 999, -- not loaded
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("does NOT leave a profile locked after a not-loaded bail (regression)", function()
				local profile = seed(1, 100)
				-- Bails in validation because user 999 isn't loaded.
				PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function()
							return true
						end,
					},
					{
						userId = 999,
						path = "currency",
						mutator = function()
							return true
						end,
					},
				})
				-- User 1 must still be mutable — it was never locked.
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 7
					return true
				end)
				expect(ok).to.equal(true)
				expect(profile.Data.currency.gold).to.equal(7)
			end)

			it("locks the profile against re-entrant mutate() during the transaction", function()
				local profile = seed(1, 100)
				local nestedResult: boolean? = nil
				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							-- The profile is locked for the lifetime of the transaction,
							-- so a nested mutate() on the same profile must be refused.
							nestedResult = PlayerDataService:mutate(1, "currency", function(cc: any)
								cc.gold = 999
								return true
							end)
							c.gold = 5
							return true
						end,
					},
				})
				expect(ok).to.equal(true)
				expect(nestedResult).to.equal(false)
				expect(profile.Data.currency.gold).to.equal(5)
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
					{ userId = 1, path = "currency", mutator = "not a function" },
					{
						userId = 1,
						path = 123,
						mutator = function()
							return true
						end,
					},
					{
						userId = "bad",
						path = "currency",
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
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 7
					return true
				end)
				expect(ok).to.equal(true)
				expect(profile.Data.currency.gold).to.equal(7)
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
						path = "currency",
						mutator = function(c: any)
							PlayerDataService:_cleanupPlayer(1)
							sessionGoneDuring = PlayerDataService:getState().sessions["1"] == nil
							c.gold = 1
							return true
						end,
					},
				})
				expect(sessionGoneDuring).to.equal(true)
				-- Re-seed the same userId (a rejoin): the session must accept mutations again.
				local profile = seed(1, 50)
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 9
					return true
				end)
				expect(ok).to.equal(true)
				expect(profile.Data.currency.gold).to.equal(9)
			end)

			it(
				"does NOT re-mirror a profile removed before the commit's mirror pass (zombie entry regression)",
				function()
					seed(1, 100)
					-- A departed player is dropped from ServerStore by _cleanupPlayer. If the post-commit
					-- mirror loop then re-synced their slice, it would leave a stale atom entry for a gone
					-- session that nothing ever removes again. Simulate the departure inside the mutator
					-- (the same code path the persist-backoff-then-leave window hits) and assert the mirror
					-- pass skips the removed user.
					PlayerDataService:transaction({
						{
							userId = 1,
							path = "currency",
							mutator = function(c: any)
								c.gold = 1
								PlayerDataService:_cleanupPlayer(1) -- player leaves mid-commit
								return true
							end,
						},
					})
					-- The removed user must NOT have been re-inserted into the reactive mirror.
					expect(ServerStore.currencies()[1]).to.equal(nil)
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
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
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
				expect(profile.Data.currency.gold).to.equal(100)
				-- ...no key was created for the missing path (the rollback snapshot cannot
				-- represent "path absent", so creation must be refused up front)...
				expect(profile.Data.quests).to.equal(nil)
				-- ...and the profile was never locked.
				local mutateOk = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 7
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
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
							return true
						end,
					},
					{
						userId = 2,
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
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
				expect(a.Data.currency.gold).to.equal(100)
				expect(b.Data.currency.gold).to.equal(50)
				-- The abort path released both locks — the profiles are mutable again.
				expect(PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 1
					return true
				end)).to.equal(true)
			end)

			it("commits in memory without forcing a save by default (persisted = false)", function()
				local profile = seedProfile(1, makeFakeProfile(makeData(100)))
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 50
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
				expect(profile.Data.currency.gold).to.equal(50)
				-- ...but no forced save was performed (the whole point of #5).
				expect(profile:_getSaveCalls()).to.equal(0)
			end)

			it("reports persisted = true when { persist = true } and the save succeeds", function()
				local profile = seedProfile(1, makeFakeProfile(makeData(100)))
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 50
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
						path = "currency",
						mutator = function(c: any)
							-- The profile is locked for the outer transaction; re-entering it must be refused
							-- so the nested commit can't wipe the outer transaction's lock state.
							nestedOk, nestedResult = PlayerDataService:transaction({
								{
									userId = 1,
									path = "currency",
									mutator = function(cc: any)
										cc.gold = 999
										return true
									end,
								},
							})
							c.gold = 5
							return true
						end,
					},
				})
				expect(ok).to.equal(true)
				expect(nestedOk).to.equal(false)
				expect(nestedResult.committed).to.equal(false)
				-- Only the outer mutation applied; the refused nested call changed nothing.
				expect(profile.Data.currency.gold).to.equal(5)
			end)

			it("rolls back and fails when a profile is inactive at the commit gate", function()
				-- Inactive from the first IsActive() call — which is now the pre-commit atomicity gate,
				-- since Phase 2 no longer force-saves (and so no longer probes IsActive first).
				local profile = seedProfile(1, makeFakeProfile(makeData(100), { activeUntilCall = 0 }))
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(result.committed).to.equal(false)
				-- Rolled back from the in-memory snapshot: the original value is restored.
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("commits in memory but reports failedUserIds when a persist save keeps failing", function()
				-- persist = true forces a save that throws on every attempt (saveFailFrom = 1), so the
				-- transaction commits in memory yet cannot be persisted this server.
				local profile = seedProfile(1, makeFakeProfile(makeData(100), { saveFailFrom = 1 }))
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 40
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
				expect(profile.Data.currency.gold).to.equal(40)
			end)

			it("treats a dispatched-but-unconfirmed save as not persisted (no OnAfterSave)", function()
				-- ProfileStore's Save() only dispatches the write; durability is confirmed by
				-- OnAfterSave. A save that returns cleanly but is never confirmed must NOT report
				-- persisted = true — that was the old behavior (pcall success == "saved").
				local profile = seedProfile(1, makeFakeProfile(makeData(100), { suppressAfterSave = true }))
				PlayerDataService:_setPersistConfirmTimeoutForTesting(0.05)
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 40
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
				expect(profile.Data.currency.gold).to.equal(40)
			end)

			it("rolls back a scalar-path operation without leaking the transaction lock", function()
				-- _schemaVersion is a scalar profile path: it passes Phase 1's existence check, so
				-- Phase 2 must snapshot it WITHOUT sift.Dictionary.copyDeep (which throws on a
				-- non-table). The old code threw there with the lock already taken, permanently
				-- refusing this user's mutate()/transaction() until they left (lock-leak regression).
				local profile = seedProfile(
					1,
					makeFakeProfile({ currency = { gold = 100, gems = 0 }, inventory = {}, _schemaVersion = 3 })
				)
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
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
				expect(profile.Data.currency.gold).to.equal(100)
				expect(profile.Data._schemaVersion).to.equal(3)
				-- And crucially: the lock was released, not leaked.
				expect(PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 7
					return true
				end)).to.equal(true)
			end)

			it("commits a transaction that touches a scalar path (snapshot stays total)", function()
				local profile = seedProfile(
					1,
					makeFakeProfile({ currency = { gold = 100, gems = 0 }, inventory = {}, _schemaVersion = 3 })
				)
				local ok, result = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 55
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
				expect(profile.Data.currency.gold).to.equal(55)
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
						path = "currency",
						mutator = function(c: any)
							c.gold = 90
							return true
						end,
					},
					{
						userId = 2,
						path = "currency",
						mutator = function(c: any)
							c.gold = 60
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
				-- sessions, janitors, and the ServerStore mirror never leak across specs.
				PlayerDataService:_cleanupPlayer(1)
				PlayerDataService:_cleanupPlayer(2)
				PlayerDataService.PlayerStore = nil
			end)

			it("loads, migrates, registers, and seeds the reactive mirror on a successful join", function()
				local profile = makeFakeSessionProfile(makeData(100))
				local getKey = installStore(profile)
				local host = makeFakeHost(1)
				PlayerDataService:_startSession(host)

				expect(getKey()).to.equal("1")
				expect(#host._kicks).to.equal(0)
				expect(profile:_getAddedUserIds()[1]).to.equal(1)
				-- A pre-versioning profile (no _schemaVersion) is treated as the v1 baseline and
				-- stamped current — the stored version was read BEFORE Reconcile backfilled it.
				expect(profile.Data._schemaVersion).to.equal(PlayerDataMigrations.CURRENT_VERSION)
				expect(PlayerDataService:getState().sessions["1"]).to.be.ok()
				-- The reactive projection is seeded at load, no separate handshake.
				expect(ServerStore.currencies()[1].gold).to.equal(100)
				-- And the session accepts writes.
				expect(PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 1
					return true
				end)).to.equal(true)
			end)

			it("kicks and registers nothing when the profile load errors", function()
				installStore(nil, "simulated datastore outage")
				local host = makeFakeHost(1)
				PlayerDataService:_startSession(host)

				expect(host._kicks[1]).to.equal("Profile load error - Please rejoin")
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
				expect(ServerStore.currencies()[1]).to.equal(nil)
			end)

			it("kicks when the store returns no profile (server shutting down)", function()
				installStore(nil)
				local host = makeFakeHost(1)
				PlayerDataService:_startSession(host)

				expect(host._kicks[1]).to.equal("Profile load fail - Please rejoin")
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
			end)

			it("refuses a profile written by a newer server (too_new) and leaves its data pristine", function()
				local data = makeData(100)
				data._schemaVersion = PlayerDataMigrations.CURRENT_VERSION + 1
				local profile = makeFakeSessionProfile(data)
				local host = makeFakeHost(1)
				installStore(profile)
				PlayerDataService:_startSession(host)

				expect(host._kicks[1]).to.equal("This server is updating - please rejoin")
				expect(profile:_wasSessionEnded()).to.equal(true)
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
				-- The newer data was restored from LastSavedData exactly as loaded — never
				-- migrated, never stamped down.
				expect(profile.Data._schemaVersion).to.equal(PlayerDataMigrations.CURRENT_VERSION + 1)
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("kicks and leaves data untouched when a migration fails", function()
				local data = makeData(100)
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
				expect(profile.Data.currency.gold).to.equal(100)
			end)

			it("ends the session quietly when the player left during load", function()
				local profile = makeFakeSessionProfile(makeData(100))
				local host = makeFakeHost(1)
				host._setPresent(false)
				installStore(profile)
				PlayerDataService:_startSession(host)

				expect(profile:_wasSessionEnded()).to.equal(true)
				expect(#host._kicks).to.equal(0)
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
				expect(ServerStore.currencies()[1]).to.equal(nil)
			end)

			it("cleans up and kicks when the session ends externally (OnSessionEnd)", function()
				local profile = makeFakeSessionProfile(makeData(100))
				local host = makeFakeHost(1)
				installStore(profile)
				PlayerDataService:_startSession(host)
				expect(PlayerDataService:getState().sessions["1"]).to.be.ok()

				profile.OnSessionEnd:Fire()

				expect(host._kicks[1]).to.equal("Profile session end - Please rejoin")
				expect(PlayerDataService:getState().sessions["1"]).to.equal(nil)
				-- The reactive mirror is swept with the session.
				expect(ServerStore.currencies()[1]).to.equal(nil)
			end)

			it("wires the live OnSave abort handler: an auto-save mid-transaction rolls back", function()
				-- The seam-based OnSave tests above exercise the abort machinery through
				-- _setProfileForTesting's connection; this proves a REAL join wires the same
				-- handler through the session janitor.
				local profile = makeFakeSessionProfile(makeData(100))
				local host = makeFakeHost(1)
				installStore(profile)
				PlayerDataService:_startSession(host)

				local ok = PlayerDataService:transaction({
					{
						userId = 1,
						path = "currency",
						mutator = function(c: any)
							c.gold = 0
							profile.OnSave:Fire() -- simulated auto-save mid-transaction
							return true
						end,
					},
				})
				expect(ok).to.equal(false)
				expect(profile.Data.currency.gold).to.equal(100)
			end)
		end)
	end)
end
