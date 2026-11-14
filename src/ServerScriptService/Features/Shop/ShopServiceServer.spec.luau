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
			-- Regular prices (no daily sale), so the numbers never depend on the day.
			ShopService:_setClock(function()
				return nil
			end)
			phase = "lobby"
			ShiftServiceServer.getShift = function()
				return { phase = phase }
			end
		end)

		afterEach(function()
			task.wait()
			ShiftServiceServer.getShift = realGetShift
			ShopService:_setClock(nil)
			for userId in seeded do
				PlayerDataService:_setProfileForTesting(userId, nil)
			end
			table.clear(seeded)
		end)

		it("spends Gleam and grants only the skin when the skin is bought alone", function()
			seed(1, 1700, 0)
			local ok, reason = ShopService:buy(1, "Pippa.BubbleBuddy")
			expect(reason).to.equal(nil)
			expect(ok).to.equal(true)
			expect(MarketplaceService:getPremium(1)).to.equal(100)
			expect(CosmeticService:owns(1, "Pippa.BubbleBuddy")).to.equal(true)
			expect(CosmeticService:owns(1, "Pippa.Bubbles")).to.equal(false)
			expect(CosmeticService:owns(1, "BubblePack")).to.equal(false)
		end)

		it("spends Gleam once and grants every item of a bundle in one go", function()
			seed(1, 2000, 0)
			local ok, reason = ShopService:buy(1, "Bundle.BubbleBuddy")
			expect(reason).to.equal(nil)
			expect(ok).to.equal(true)
			expect(MarketplaceService:getPremium(1)).to.equal(100)
			for _, id in
				{ "Pippa.BubbleBuddy", "Pippa.Bubbles", "BubblePack", "BubblePack.Yay", "Pippa.BubbleBuddyIdle" }
			do
				expect(CosmeticService:owns(1, id)).to.equal(true)
			end
		end)

		it("spends Credits for an employee", function()
			seed(1, 0, 5500)
			local ok = ShopService:buy(1, "Prickles")
			expect(ok).to.equal(true)
			expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(500)
			expect(CosmeticService:owns(1, "Prickles")).to.equal(true)
		end)

		it("hires Cappy for exactly 5000 Credits and refuses a repeated request without spending again", function()
			seed(1, 0, 10000)
			local player = { UserId = 1, Name = "CappyBuyer" }
			ShopService._onBuyRequest({ offer = "Cappy" }, player)
			expect(CosmeticService:owns(1, "Cappy")).to.equal(true)
			expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(5000)
			ShopService._onBuyRequest({ offer = "Cappy" }, player)
			expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(5000)
		end)

		it("rejects Cappy below 5000 Credits without granting or spending", function()
			seed(1, 0, 4999)
			local ok, reason = ShopService:buy(1, "Cappy")
			expect(ok).to.equal(false)
			expect(reason).to.equal("short")
			expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(4999)
			expect(CosmeticService:owns(1, "Cappy")).to.equal(false)
		end)

		it("leaves Credits unchanged when the entitlement write fails", function()
			seed(1, 0, 5000)
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
			expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(5000)
			expect(CosmeticService:owns(1, "Cappy")).to.equal(false)
		end)

		it("changes nothing when the balance is short", function()
			seed(1, 1599, 0)
			local ok, reason = ShopService:buy(1, "Pippa.BubbleBuddy")
			expect(ok).to.equal(false)
			expect(reason).to.equal("short")
			expect(MarketplaceService:getPremium(1)).to.equal(1599)
			expect(CosmeticService:owns(1, "Pippa.BubbleBuddy")).to.equal(false)
		end)

		it("never charges twice for something already owned", function()
			seed(1, 4000, 0)
			expect(ShopService:buy(1, "Pippa.BubbleBuddy")).to.equal(true)
			local ok, reason = ShopService:buy(1, "Pippa.BubbleBuddy")
			expect(ok).to.equal(false)
			expect(reason).to.equal("owned")
			expect(MarketplaceService:getPremium(1)).to.equal(2400)
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
			seed(1, 2000, 0)
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
			seed(1, 2000, 0)
			local fakePlayer = { UserId = 1, Name = "TestPlayer" }
			expect(function()
				ShopService._onBuyRequest({ offer = 3 }, fakePlayer)
				ShopService._onBuyRequest(nil, fakePlayer)
			end).never.to.throw()
			expect(MarketplaceService:getPremium(1)).to.equal(2000)
			ShopService._onBuyRequest({ offer = "Pippa.BubbleBuddy" }, fakePlayer)
			expect(CosmeticService:owns(1, "Pippa.BubbleBuddy")).to.equal(true)
		end)

		it("never charges more than the price the player saw", function()
			seed(1, 9999, 0)
			local offer = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry).get("Pippa.Bubbles")
			local ok, reason = ShopService:buy(1, "Pippa.Bubbles", 0, offer.price - 100)
			expect(ok).to.equal(false)
			expect(reason).to.equal("price changed")
			expect(MarketplaceService:getPremium(1)).to.equal(9999)
			expect(ShopService:buy(1, "Pippa.Bubbles", 0, offer.price)).to.equal(true)
			expect(MarketplaceService:getPremium(1)).to.equal(9999 - offer.price)
		end)

		it("charges today's sale price on the server's clock", function()
			local ShopPriceRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopPriceRules)
			local NOON = 1792929600
			ShopService:_setClock(function()
				return NOON
			end)
			local id = next(ShopPriceRules.daily(NOON))
			local registry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
			local sale = ShopPriceRules.forPlayer(registry.get(id), function()
				return false
			end, NOON)
			expect(sale.price < registry.get(id).price).to.equal(true)
			seed(1, 9999, 9999)
			expect(ShopService:buy(1, id, 0, sale.price)).to.equal(true)
			local spent = if sale.currency == "gleam"
				then 9999 - MarketplaceService:getPremium(1)
				else 9999 - CurrencyService:getCurrencyAmount(1, "credits")
			expect(spent).to.equal(sale.price)
		end)

		describe("bundles you own part of", function()
			local ShopPriceRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopPriceRules)
			local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)

			it("charges only the missing part's share and grants what is missing", function()
				local bundle
				for _, offer in ShopRegistry.all() do
					if #offer.items > 1 and offer.currency == "gleam" then
						bundle = offer
						break
					end
				end
				expect(bundle).to.be.ok()
				seed(1, 9999, 0)
				local first = bundle.items[1]
				expect(ShopService:buy(1, first)).to.equal(true)
				local afterFirst = MarketplaceService:getPremium(1)
				local priced = ShopPriceRules.forPlayer(bundle, function(id)
					return id == first
				end)
				expect(priced.price < bundle.price).to.equal(true)
				local ok, reason = ShopService:buy(1, bundle.id)
				expect(reason).to.equal(nil)
				expect(ok).to.equal(true)
				expect(MarketplaceService:getPremium(1)).to.equal(afterFirst - priced.price)
				for _, id in bundle.items do
					expect(CosmeticService:owns(1, id)).to.equal(true)
				end
			end)

			it("reveals only the items that are new", function()
				local bundle
				for _, offer in ShopRegistry.all() do
					if #offer.items > 1 and offer.currency == "gleam" then
						bundle = offer
						break
					end
				end
				seed(1, 9999, 0)
				expect(ShopService:buy(1, bundle.items[1])).to.equal(true)
				task.wait()
				local events = {}
				local listening = CosmeticService.granted:Connect(function(event)
					table.insert(events, event)
				end)
				expect(ShopService:buy(1, bundle.id)).to.equal(true)
				task.wait()
				listening:Disconnect()
				expect(#events).to.equal(1)
				expect(#events[1].ids).to.equal(#bundle.items - 1)
				expect(table.find(events[1].ids, bundle.items[1])).to.equal(nil)
			end)
		end)

		describe("Gleam pays the rest", function()
			local ShopTopUpRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopTopUpRules)

			it("hires with the Credits the player has plus Gleam for the rest, in one go", function()
				seed(1, 500, 4705)
				local plan = ShopTopUpRules.plan("credits", 5000, 4705)
				local ok, reason = ShopService:buy(1, "Cappy", plan.gleam)
				expect(reason).to.equal(nil)
				expect(ok).to.equal(true)
				expect(CosmeticService:owns(1, "Cappy")).to.equal(true)
				expect(MarketplaceService:getPremium(1)).to.equal(500 - plan.gleam)
				-- The rounding stays with the player.
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(4705 - plan.spend)
			end)

			it("hires from zero Credits with Gleam alone (the starting-employee pick too)", function()
				local plan = ShopTopUpRules.plan("credits", 5000, 0)
				-- Its own player: the request is rate-limited per player, and earlier specs sent user 1's.
				seed(7, plan.gleam, 0)
				local player = { UserId = 7, Name = "GleamHirer" }
				ShopService._onBuyRequest({ offer = "Prickles", gleam = plan.gleam }, player)
				expect(CosmeticService:owns(7, "Prickles")).to.equal(true)
				expect(MarketplaceService:getPremium(7)).to.equal(0)
				expect(CurrencyService:getCurrencyAmount(7, "credits")).to.equal(0)
			end)

			it("refuses when the rest costs more Gleam than the player said yes to", function()
				seed(1, 500, 4705)
				local plan = ShopTopUpRules.plan("credits", 5000, 4705)
				local ok, reason = ShopService:buy(1, "Cappy", plan.gleam - 1)
				expect(ok).to.equal(false)
				expect(reason).to.equal("top up changed")
				expect(MarketplaceService:getPremium(1)).to.equal(500)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(4705)
				expect(CosmeticService:owns(1, "Cappy")).to.equal(false)
			end)

			it("refuses when the player has too little Gleam for the rest", function()
				local plan = ShopTopUpRules.plan("credits", 5000, 4705)
				seed(1, plan.gleam - 1, 4705)
				local ok, reason = ShopService:buy(1, "Cappy", plan.gleam)
				expect(ok).to.equal(false)
				expect(reason).to.equal("short")
				expect(MarketplaceService:getPremium(1)).to.equal(plan.gleam - 1)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(4705)
			end)

			it("never tops up without the player's yes", function()
				seed(1, 500, 4705)
				local _, reason = ShopService:buy(1, "Cappy")
				expect(reason).to.equal("short")
				expect(MarketplaceService:getPremium(1)).to.equal(500)
			end)

			it("takes no Gleam when the Credits already cover it", function()
				seed(1, 500, 5500)
				expect(ShopService:buy(1, "Cappy", 30)).to.equal(true)
				expect(MarketplaceService:getPremium(1)).to.equal(500)
				expect(CurrencyService:getCurrencyAmount(1, "credits")).to.equal(500)
			end)

			it("never tops up a Gleam item", function()
				seed(1, 1100, 99999)
				local ok, reason = ShopService:buy(1, "Pippa.BubbleBuddy", 100)
				expect(ok).to.equal(false)
				expect(reason).to.equal("short")
				expect(MarketplaceService:getPremium(1)).to.equal(1100)
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
