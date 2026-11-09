--[[
	Unit tests for LockerServiceServer: real fake profiles through `_setProfileForTesting` and the real transaction
	machinery, with `deps` stubbed through `_setDeps` (shift lock, PolicyService restriction, pool, RNG, clock).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local sift = require(ReplicatedStorage.Packages.sift)
local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
local LockerRules = require(ReplicatedStorage.Shared.Features.Locker.Rules.LockerRules)
local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local CosmeticService = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
local CurrencyService = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local MarketplaceService = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local LockerService = require(ServerScriptService.Features.Locker.LockerServiceServer)

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

local function makeProfileData(gloom, gleam, keys, pity)
	local slots = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = {
			currency = { credits = 0, gloom = gloom or 0 },
			inventory = { items = {} },
			equippedTitle = {},
		}
	end
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			itemMint = { nextUid = 1 },
			premium = { balance = gleam or 0 },
			receipts = { ids = {} },
			firstSeen = { at = 0 },
			loadout = { current = "Pippa", picked = true, looks = {}, stickers = { "", "", "", "" }, seen = {} },
			lockers = { keys = keys or {}, pity = pity or {}, opened = 0 },
			entitlements = { owned = {} },
			settings = { values = {} },
			dailyReward = { lastDay = 0, streak = 0 },
			rank = { season = "mvp-1", xp = 0, lastAwardedRunId = "" },
			titles = { earned = {} },
			coffee = { vouchers = 0 },
		},
		slots = slots,
	}
end

return function()
	describe("LockerServiceServer", function()
		local player = { UserId = 1, Name = "TestPlayer" }
		local seeded = {}
		local locked, restricted, clock, rolls, gleamPool, openedSent, refusedSent

		local function seed(userId, gloom, gleam, keys, pity)
			PlayerDataService:_setProfileForTesting(userId, makeFakeProfile(makeProfileData(gloom, gleam, keys, pity)))
			seeded[userId] = true
		end

		beforeEach(function()
			locked = false
			restricted = false
			clock = 100
			rolls = { 0.0, 0.0 }
			gleamPool = {
				{
					id = "Pippa.BubbleBuddy",
					kind = "skin",
					name = "Bubble Buddy",
					rarity = "legendary",
					source = "gleamLocker",
					employee = "Pippa",
					bundle = { "Pippa.Bubbles", "BubblePack" },
					lore = "",
				},
			}
			openedSent = {}
			refusedSent = {}
			local rollIndex = 0
			LockerService._setDeps({
				isLocked = function()
					return locked
				end,
				restricted = function()
					return restricted
				end,
				pool = function(locker)
					if locker.id == "gleam" then
						return gleamPool
					end
					return LockerRules.pool(locker)
				end,
				nextNumber = function()
					rollIndex += 1
					return rolls[rollIndex] or 0.0
				end,
				now = function()
					return clock
				end,
				sendOpened = function(_, outcome)
					table.insert(openedSent, outcome)
				end,
				sendRefused = function(_, locker, reason)
					table.insert(refusedSent, { locker = locker, reason = reason })
				end,
				sendStatus = function() end,
			})
		end)

		afterEach(function()
			task.wait()
			LockerService._setDeps(nil)
			for userId in seeded do
				PlayerDataService:_setProfileForTesting(userId, nil)
			end
			table.clear(seeded)
		end)

		it("buys a key and opens in one transaction, granting the item and saving pity", function()
			seed(1, 300, 0)
			local outcome, reason = LockerService:open(player, "gloom")
			expect(reason).to.equal(nil)
			expect(outcome ~= nil).to.equal(true)
			expect(outcome.rarity).to.equal("uncommon")
			expect(outcome.duplicate).to.equal(false)
			expect(outcome.pity).to.equal(1)
			expect(CurrencyService:getCurrencyAmount(1, "gloom")).to.equal(0)
			expect(CosmeticService:owns(1, outcome.item)).to.equal(true)
			local saved = LockerService:getLockers(1)
			expect(saved.pity.gloom).to.equal(1)
			expect(saved.opened).to.equal(1)
		end)

		it("spends a held key before touching currency", function()
			seed(1, 500, 0, { gloom = 2 }, { gloom = 3 })
			local outcome = LockerService:open(player, "gloom")
			expect(outcome ~= nil).to.equal(true)
			expect(CurrencyService:getCurrencyAmount(1, "gloom")).to.equal(500)
			local saved = LockerService:getLockers(1)
			expect(saved.keys.gloom).to.equal(1)
			expect(saved.pity.gloom).to.equal(4)
		end)

		it("forces an Epic+ at the pity number and resets saved pity to 0", function()
			local pityAt = LockerRules.odds(LockerConstants.LOCKERS.gloom).pityAt
			seed(1, 300, 0, {}, { gloom = pityAt - 1 })
			rolls = { 0.0, 0.0 }
			local outcome = LockerService:open(player, "gloom")
			expect(outcome ~= nil).to.equal(true)
			expect(outcome.guaranteed).to.equal(true)
			expect(outcome.rarity).to.equal("epic")
			expect(outcome.pity).to.equal(0)
			expect(LockerService:getLockers(1).pity.gloom).to.equal(0)
		end)

		it("refunds part of the key price when the rolled item is already owned", function()
			seed(1, 600, 0)
			local first = LockerService:open(player, "gloom")
			expect(first.duplicate).to.equal(false)
			expect(CurrencyService:getCurrencyAmount(1, "gloom")).to.equal(300)
			clock += 2
			rolls = { 0.0, 0.0 }
			local second = LockerService:open(player, "gloom")
			expect(second.item).to.equal(first.item)
			expect(second.duplicate).to.equal(true)
			expect(second.refund).to.equal(LockerRules.refund(LockerConstants.LOCKERS.gloom, first.rarity))
			expect(CurrencyService:getCurrencyAmount(1, "gloom")).to.equal(second.refund)
		end)

		it("refuses in a shift, when restricted on a paid Locker, on an empty pool, or when short", function()
			seed(1, 200, 500)
			locked = true
			expect(select(2, LockerService:open(player, "gloom"))).to.equal("locked during a shift")
			locked = false

			expect(select(2, LockerService:open(player, "gloom"))).to.equal("short")

			restricted = true
			expect(select(2, LockerService:open(player, "gleam"))).to.equal("restricted")
			-- Gloom Locker is earned-only, so restricted players can still open it when they have a key.
			LockerService:addKeys(1, "gloom", 1)
			expect(LockerService:open(player, "gloom") ~= nil).to.equal(true)

			restricted = false
			gleamPool = {}
			clock += 2
			expect(select(2, LockerService:open(player, "gleam"))).to.equal("empty")
		end)

		it("lets a restricted player buy a paid Locker's item directly at the raised price", function()
			seed(1, 0, 1600)
			restricted = false
			expect(select(2, LockerService:buyDirect(player, "gleam", "Pippa.BubbleBuddy"))).to.equal("not restricted")

			restricted = true
			local ok, reason = LockerService:buyDirect(player, "gleam", "Pippa.BubbleBuddy")
			expect(reason).to.equal(nil)
			expect(ok).to.equal(true)
			expect(MarketplaceService:getPremium(1)).to.equal(100)
			expect(CosmeticService:owns(1, "Pippa.BubbleBuddy")).to.equal(true)
			expect(CosmeticService:owns(1, "Pippa.Bubbles")).to.equal(true)
		end)
	end)
end
