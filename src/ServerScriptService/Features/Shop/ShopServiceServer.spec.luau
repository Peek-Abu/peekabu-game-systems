--[[
	Unit tests for ShopServiceServer: real fake profiles through `_setProfileForTesting` and the real transaction
	machinery (the CosmeticServiceServer.spec strategy). The shift phase is stubbed on ShiftServiceServer.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local CosmeticService = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local CurrencyService = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local MarketplaceService = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local ShopService = require(ServerScriptService.Features.Shop.ShopServiceServer)
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
			for fn in handlers do
				fn(...)
			end
		end,
	}
end

local function makeFakeProfile(data)
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

local function makeProfileData(gleam, credits)
	local slots = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = { currency = { credits = credits, gloom = 0 }, inventory = { items = {} }, equippedTitle = {} }
	end
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			itemMint = { nextUid = 1 },
			premium = { balance = gleam },
			receipts = { ids = {} },
			firstSeen = { at = 0 },
			loadout = { current = "Pippa", picked = true, looks = {}, stickers = { "", "", "", "" }, seen = {} },
			entitlements = { owned = {} },
			settings = { values = {} },
			dailyReward = { lastDay = 0, streak = 0 },
			rank = { season = "mvp-1", xp = 0, lastAwardedRunId = "" },
			titles = { earned = {} },
			coffee = { seconds = 0, since = 0 },
			deals = { bought = {}, picks = {} },
			places = { owned = {} },
		},
		slots = slots,
	}
end

return function()
	describe("ShopServiceServer", function()
		local seeded = {}
		local realGetShift = ShiftServiceServer.getShift
		local phase = "lobby"

		local function seed(userId, gleam, credits)
			PlayerDataService:_setProfileForTesting(userId, makeFakeProfile(makeProfileData(gleam, credits)))
			seeded[userId] = true
		end

		beforeEach(function()
			phase = "lobby"
			ShiftServiceServer.getShift = function()
				return { phase = phase }
			end
		end)

		afterEach(function()
			task.wait()
			ShiftServiceServer.getShift = realGetShift
			for userId in seeded do
				PlayerDataService:_setProfileForTesting(userId, nil)
			end
			table.clear(seeded)
		end)

		it("spends Gleam and grants the item and its bundle in one go", function()
			seed(1, 1600, 0)
			local ok, reason = ShopService:buy(1, "Pippa.BubbleBuddy")
			expect(reason).to.equal(nil)
			expect(ok).to.equal(true)
			expect(MarketplaceService:getPremium(1)).to.equal(100)
			expect(CosmeticService:owns(1, "Pippa.BubbleBuddy")).to.equal(true)
			expect(CosmeticService:owns(1, "Pippa.Bubbles")).to.equal(true)
			expect(CosmeticService:owns(1, "BubblePack")).to.equal(true)
		end)

		it("spends Credits for an employee", function()
			seed(1, 0, 3000)
			local ok = ShopService:buy(1, "Prickles")
			expect(ok).to.equal(true)
			expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(500)
			expect(CosmeticService:owns(1, "Prickles")).to.equal(true)
		end)

		it("hires Cappy for exactly 2500 Credits and refuses a repeated request without spending again", function()
			seed(1, 0, 5000)
			local player = { UserId = 1, Name = "CappyBuyer" }
			ShopService._onBuyRequest({ offer = "Cappy" }, player)
			expect(CosmeticService:owns(1, "Cappy")).to.equal(true)
			expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(2500)
			ShopService._onBuyRequest({ offer = "Cappy" }, player)
			expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(2500)
		end)

		it("rejects Cappy below 2500 Credits without granting or spending", function()
			seed(1, 0, 2499)
			local ok, reason = ShopService:buy(1, "Cappy")
			expect(ok).to.equal(false)
			expect(reason).to.equal("short")
			expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(2499)
			expect(CosmeticService:owns(1, "Cappy")).to.equal(false)
		end)

		it("leaves Credits unchanged when the entitlement write fails", function()
			seed(1, 0, 2500)
			local original = CosmeticService.grantOps
			CosmeticService.grantOps = function()
				return {
					{
						userId = 1,
						path = "account.entitlements",
						mutator = function()
							return false
						end,
					},
				}
			end
			local called, ok = pcall(function()
				return ShopService:buy(1, "Cappy")
			end)
			CosmeticService.grantOps = original
			expect(called).to.equal(true)
			expect(ok).to.equal(false)
			expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(2500)
			expect(CosmeticService:owns(1, "Cappy")).to.equal(false)
		end)

		it("changes nothing when the balance is short", function()
			seed(1, 1499, 0)
			local ok, reason = ShopService:buy(1, "Pippa.BubbleBuddy")
			expect(ok).to.equal(false)
			expect(reason).to.equal("short")
			expect(MarketplaceService:getPremium(1)).to.equal(1499)
			expect(CosmeticService:owns(1, "Pippa.BubbleBuddy")).to.equal(false)
		end)

		it("never charges twice for something already owned", function()
			seed(1, 4000, 0)
			expect(ShopService:buy(1, "Pippa.BubbleBuddy")).to.equal(true)
			local ok, reason = ShopService:buy(1, "Pippa.BubbleBuddy")
			expect(ok).to.equal(false)
			expect(reason).to.equal("owned")
			expect(MarketplaceService:getPremium(1)).to.equal(2500)
		end)

		it("refuses during a shift, an unknown offer, and a player with no profile", function()
			seed(1, 9999, 9999)
			phase = "running"
			local _, locked = ShopService:buy(1, "Pippa.BubbleBuddy")
			expect(locked).to.equal("locked during a shift")
			phase = "lobby"
			local _, unknown = ShopService:buy(1, "Nope")
			expect(unknown).to.equal("unknown offer")
			local _, missing = ShopService:buy(2, "Pippa.BubbleBuddy")
			expect(missing).to.equal("no profile loaded")
			expect(MarketplaceService:getPremium(1)).to.equal(9999)
		end)

		it("announces the purchase for the reveal", function()
			seed(1, 1500, 0)
			local events = {}
			local listening = CosmeticService.granted:Connect(function(event)
				table.insert(events, event)
			end)
			ShopService:buy(1, "Pippa.BubbleBuddy")
			task.wait()
			listening:Disconnect()
			expect(#events).to.equal(1)
			expect(events[1].source).to.equal("shop")
			expect(events[1].ids[1]).to.equal("Pippa.BubbleBuddy")
		end)

		it("buys from a well-formed request and drops a malformed one", function()
			seed(1, 1500, 0)
			local fakePlayer = { UserId = 1, Name = "TestPlayer" }
			expect(function()
				ShopService._onBuyRequest({ offer = 3 }, fakePlayer)
				ShopService._onBuyRequest(nil, fakePlayer)
			end).never.to.throw()
			expect(MarketplaceService:getPremium(1)).to.equal(1500)
			ShopService._onBuyRequest({ offer = "Pippa.BubbleBuddy" }, fakePlayer)
			expect(CosmeticService:owns(1, "Pippa.BubbleBuddy")).to.equal(true)
		end)

		describe("Gleam pays the rest", function()
			local ShopTopUpRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopTopUpRules)

			it("hires with the Credits the player has plus Gleam for the rest, in one go", function()
				seed(1, 500, 2205)
				local plan = ShopTopUpRules.plan("credits", 2500, 2205)
				local ok, reason = ShopService:buy(1, "Cappy", plan.gleam)
				expect(reason).to.equal(nil)
				expect(ok).to.equal(true)
				expect(CosmeticService:owns(1, "Cappy")).to.equal(true)
				expect(MarketplaceService:getPremium(1)).to.equal(500 - plan.gleam)
				-- The rounding stays with the player.
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(2205 - plan.spend)
			end)

			it("hires from zero Credits with Gleam alone (the starting-employee pick too)", function()
				local plan = ShopTopUpRules.plan("credits", 2500, 0)
				seed(1, plan.gleam, 0)
				local player = { UserId = 1, Name = "GleamHirer" }
				ShopService._onBuyRequest({ offer = "Prickles", gleam = plan.gleam }, player)
				expect(CosmeticService:owns(1, "Prickles")).to.equal(true)
				expect(MarketplaceService:getPremium(1)).to.equal(0)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(0)
			end)

			it("refuses when the rest costs more Gleam than the player said yes to", function()
				seed(1, 500, 2205)
				local plan = ShopTopUpRules.plan("credits", 2500, 2205)
				local ok, reason = ShopService:buy(1, "Cappy", plan.gleam - 1)
				expect(ok).to.equal(false)
				expect(reason).to.equal("top up changed")
				expect(MarketplaceService:getPremium(1)).to.equal(500)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(2205)
				expect(CosmeticService:owns(1, "Cappy")).to.equal(false)
			end)

			it("refuses when the player has too little Gleam for the rest", function()
				local plan = ShopTopUpRules.plan("credits", 2500, 2205)
				seed(1, plan.gleam - 1, 2205)
				local ok, reason = ShopService:buy(1, "Cappy", plan.gleam)
				expect(ok).to.equal(false)
				expect(reason).to.equal("short")
				expect(MarketplaceService:getPremium(1)).to.equal(plan.gleam - 1)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(2205)
			end)

			it("never tops up without the player's yes", function()
				seed(1, 500, 2205)
				local _, reason = ShopService:buy(1, "Cappy")
				expect(reason).to.equal("short")
				expect(MarketplaceService:getPremium(1)).to.equal(500)
			end)

			it("takes no Gleam when the Credits already cover it", function()
				seed(1, 500, 3000)
				expect(ShopService:buy(1, "Cappy", 30)).to.equal(true)
				expect(MarketplaceService:getPremium(1)).to.equal(500)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(500)
			end)

			it("never tops up a Gleam item", function()
				seed(1, 1400, 99999)
				local ok, reason = ShopService:buy(1, "Pippa.BubbleBuddy", 100)
				expect(ok).to.equal(false)
				expect(reason).to.equal("short")
				expect(MarketplaceService:getPremium(1)).to.equal(1400)
			end)

			it("gives other purchases the same payment (payOps)", function()
				seed(1, 500, 95)
				local ops, refusal, plan = ShopService:payOps(1, "credits", 100, 1)
				expect(refusal).to.equal(nil)
				expect(plan.gleam).to.equal(ShopTopUpRules.gleamFor("credits", 5))
				local committed = PlayerDataService:transaction(ops)
				expect(committed).to.equal(true)
				expect(MarketplaceService:getPremium(1)).to.equal(500 - plan.gleam)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(95 - plan.spend)
			end)
		end)
	end)
end
