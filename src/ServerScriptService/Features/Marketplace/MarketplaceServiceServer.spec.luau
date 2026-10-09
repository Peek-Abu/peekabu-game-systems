--[[
	Unit tests for MarketplaceServiceServer's premium slice. Same strategy as the Title spec: seed REAL fake
	profiles via `_setProfileForTesting` and drive the REAL mutate()/transaction()/validator machinery.

	The receipt flow's decisions are MarketplaceReceiptSystem.spec (with fakes); ProcessReceipt itself needs
	a real buyer on the server, so it is verified in Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local MarketplaceService = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local MarketplaceConstants = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceConstants)
local sift = require(ReplicatedStorage.Packages.sift)

local function fakeSignal()
	local handlers = {}
	return {
		Connect = function(_self, fn)
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

local function makeFakeProfile(data)
	local profile
	profile = {
		Data = data,
		LastSavedData = sift.Dictionary.copyDeep(data),
		OnSave = fakeSignal(),
		OnAfterSave = fakeSignal(),
		IsActive = function()
			return true
		end,
		-- A save that lands at once, so a persisted transaction is confirmed.
		Save = function()
			profile.LastSavedData = sift.Dictionary.copyDeep(profile.Data)
			profile.OnAfterSave:Fire(profile.LastSavedData)
		end,
	}
	return profile
end

local function makeProfileData()
	local slots = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = { currency = {}, inventory = { items = {} }, equippedTitle = {} }
	end
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			itemMint = { nextUid = 1 },
			titles = { earned = {} },
			premium = { balance = 0 },
			receipts = { ids = {} },
		},
		slots = slots,
	}
end

return function()
	describe("MarketplaceServiceServer premium", function()
		local seeded = {}

		local function seed(userId)
			local profile = makeFakeProfile(makeProfileData())
			seeded[userId] = true
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile
		end

		afterEach(function()
			for userId in seeded do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
			end
			seeded = {}
		end)

		it("reads a fresh balance of 0, and nil for an unloaded profile", function()
			seed(1)
			expect(MarketplaceService:getPremium(1)).to.equal(0)
			expect(MarketplaceService:getPremium(999)).to.equal(nil)
		end)

		it("adds and spends premium", function()
			seed(1)
			expect(MarketplaceService:addPremium(1, 50)).to.equal(true)
			expect(MarketplaceService:spendPremium(1, 20)).to.equal(true)
			expect(MarketplaceService:getPremium(1)).to.equal(30)
		end)

		it("refuses to spend more than the balance, spending nothing", function()
			seed(1)
			MarketplaceService:addPremium(1, 10)
			expect((MarketplaceService:spendPremium(1, 11))).to.equal(false)
			expect(MarketplaceService:getPremium(1)).to.equal(10)
		end)

		it("is capped by the data layer, whatever path writes it", function()
			local profile = seed(1)
			profile.Data.account.premium.balance = MarketplaceConstants.MAX_PREMIUM
			local ok, reason = MarketplaceService:addPremium(1, 1)
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
			expect(MarketplaceService:getPremium(1)).to.equal(MarketplaceConstants.MAX_PREMIUM)

			-- A raw transaction op that bypasses the service's methods is refused too.
			local committed = PlayerDataService:transaction({
				MarketplaceService:premiumOp(1, function(premium)
					premium.balance = -5
					return true
				end),
			})
			expect(committed).to.equal(false)
		end)

		it("rejects a non-positive amount loudly", function()
			seed(1)
			expect(function()
				MarketplaceService:addPremium(1, 0)
			end).to.throw()
			expect(function()
				MarketplaceService:spendPremium(1, -3)
			end).to.throw()
		end)

		it("composes into a persisted transaction with another slice", function()
			seed(1)
			MarketplaceService:addPremium(1, 100)
			local committed, result = PlayerDataService:transaction({
				MarketplaceService:premiumOp(1, function(premium)
					if premium.balance < 60 then
						return false
					end
					premium.balance -= 60
					return true
				end),
				{
					userId = 1,
					path = "account.titles",
					mutator = function(titles)
						titles.earned["spec-premium-title"] = true
						return true
					end,
				},
			}, { persist = true })
			expect(committed).to.equal(true)
			expect(result.persisted).to.equal(true)
			expect(MarketplaceService:getPremium(1)).to.equal(40)
		end)
	end)

	describe("ProcessReceipt boundary", function()
		it("asks Roblox to retry a malformed receipt", function()
			local decision = MarketplaceService:_processReceipt({ PurchaseId = 5 })
			expect(decision).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
		end)

		it("asks Roblox to retry a receipt for an unregistered product", function()
			local decision = MarketplaceService:_processReceipt({
				PurchaseId = "spec-receipt",
				PlayerId = 1,
				ProductId = 990009999,
				CurrencySpent = 5,
			})
			expect(decision).to.equal(Enum.ProductPurchaseDecision.NotProcessedYet)
		end)
	end)
end
