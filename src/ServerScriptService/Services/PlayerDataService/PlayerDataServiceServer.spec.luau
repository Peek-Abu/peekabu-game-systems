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
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local sift = require(ReplicatedStorage.Packages.sift)

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

local function makeFakeProfile(data: any)
	local profile: any = {
		Data = data,
		LastSavedData = sift.Dictionary.copyDeep(data),
		OnSave = fakeSignal(),
		OnAfterSave = fakeSignal(),
	}
	function profile:IsActive(): boolean
		return true
	end
	function profile:Save()
		self.LastSavedData = sift.Dictionary.copyDeep(self.Data)
		self.OnSave:Fire()
		self.OnAfterSave:Fire()
	end
	return profile
end

local function makeData(gold: number)
	return { currency = { gold = gold, gems = 0 }, inventory = {} }
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
			-- Clear seeded profiles from the real registry so specs stay isolated.
			for userId in profiles do
				PlayerDataService:_setProfileForTesting(userId, nil)
			end
			profiles = {}
		end)

		local function seed(userId: number, gold: number)
			local profile = makeFakeProfile(makeData(gold))
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

			it("returns false when the mutator reports no change", function()
				local profile = seed(1, 100)
				local ok = PlayerDataService:mutate(1, "currency", function(c: any)
					c.gold = 999
					return false
				end)
				expect(ok).to.equal(false)
				-- The mutator body still ran; the service only reports "no change".
				expect(profile.Data.currency.gold).to.equal(999)
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
		end)

		-- =====================================================================
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
		end)
	end)
end
