--[[
	Unit tests for DailyRewardServiceServer. Same strategy as the Title spec: seed REAL fake profiles via
	`_setProfileForTesting` and drive the REAL mutate()/transaction()/validator machinery.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local DailyRewardService = require(ServerScriptService.Features.DailyReward.DailyRewardServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
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
			entitlements = { owned = {} },
			settings = { values = {} },
			dailyReward = { lastDay = 0, streak = 0 },
		},
		slots = slots,
	}
end

local DAY = 86400

return function()
	describe("DailyRewardServiceServer", function()
		local seeded = {}
		local now = DAY * 1000

		local function seed(userId)
			local profile = makeFakeProfile(makeProfileData())
			seeded[userId] = true
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile, { UserId = userId, Name = `Spec{userId}` }
		end

		beforeEach(function()
			now = DAY * 1000
			DailyRewardService:_setClock(function()
				return now
			end)
		end)

		afterEach(function()
			DailyRewardService:_setClock(nil)
			DailyRewardService:setRewards(nil)
			for userId in seeded do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
			end
			seeded = {}
		end)

		it("claims day 1 once, then refuses until tomorrow", function()
			local profile, player = seed(1)
			expect(DailyRewardService:status(player).claimable).to.equal(true)
			expect(DailyRewardService:claim(player)).to.equal(true)
			expect(profile.Data.account.dailyReward.streak).to.equal(1)
			local ok, reason = DailyRewardService:claim(player)
			expect(ok).to.equal(false)
			expect(reason).to.equal("already claimed today")
			now += DAY
			expect(DailyRewardService:claim(player)).to.equal(true)
			expect(profile.Data.account.dailyReward.streak).to.equal(2)
		end)

		it("restarts the streak after a missed day", function()
			local profile, player = seed(1)
			DailyRewardService:claim(player)
			now += DAY * 3
			DailyRewardService:claim(player)
			expect(profile.Data.account.dailyReward.streak).to.equal(1)
		end)

		it("commits the reward with the claim, telling the handler the reward day", function()
			local profile, player = seed(1)
			local seenDay = nil
			DailyRewardService:setRewards(function(_player, cycleDay)
				seenDay = cycleDay
				return {
					{
						userId = 1,
						path = "account.titles",
						mutator = function(titles)
							titles.earned["spec-daily"] = true
							return true
						end,
					},
				}
			end)
			expect(DailyRewardService:claim(player)).to.equal(true)
			expect(seenDay).to.equal(1)
			expect(profile.Data.account.titles.earned["spec-daily"]).to.equal(true)
		end)

		it("records nothing when the reward cannot be granted", function()
			local profile, player = seed(1)
			DailyRewardService:setRewards(function()
				return {
					{
						userId = 1,
						path = "account.titles",
						mutator = function()
							return false
						end,
					},
				}
			end)
			expect((DailyRewardService:claim(player))).to.equal(false)
			expect(profile.Data.account.dailyReward.streak).to.equal(0)
		end)

		it("reports an unloaded profile and resets a streak", function()
			local ok, reason = DailyRewardService:claim({ UserId = 999, Name = "Nobody" })
			expect(ok).to.equal(false)
			expect(reason).to.equal("profile not loaded")
			local profile, player = seed(1)
			DailyRewardService:claim(player)
			expect(DailyRewardService:reset(1)).to.equal(true)
			expect(profile.Data.account.dailyReward.lastDay).to.equal(0)
		end)
	end)
end
