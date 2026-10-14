--[[
	Unit tests for RankServiceServer. Same strategy as the DailyReward spec: seed REAL fake profiles via
	`_setProfileForTesting` and drive the REAL mutate()/validator machinery; the session-only path runs through the
	`_setPersist` seam and the season reset through `_setSeason`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local RankConstants = require(ReplicatedStorage.Shared.Features.Rank.Data.RankConstants)
local RankService = require(ServerScriptService.Features.Rank.RankServiceServer)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)
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

local function makeProfileData(rank)
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
			rank = rank or { season = RankConstants.RANK_SEASON, xp = 0, lastAwardedRunId = "" },
		},
		slots = slots,
	}
end

local function facts(overrides)
	local base = {
		worked = true,
		quotaMet = true,
		items = 4,
		overtimeSalvage = 0,
		extracted = true,
		caught = false,
		crewExtracted = true,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function publicXp(userId)
	local entry = StateSyncPublicPlayerStore.get(userId)
	return if entry ~= nil then entry[RankConstants.PUBLIC_XP_FIELD] else nil
end

return function()
	describe("RankServiceServer", function()
		local seeded = {}
		local realMutate = PlayerDataService.mutate

		-- Counts every PlayerDataService:mutate call on the rank slice (the slice accessor looks `mutate` up at
		-- call time), still running the real one.
		local function spyRankMutates()
			local calls = { count = 0 }
			PlayerDataService.mutate = function(self, userId, path, mutator)
				if path == "account.rank" then
					calls.count += 1
				end
				return realMutate(self, userId, path, mutator)
			end
			return calls
		end

		local function seed(userId, rank)
			local profile = makeFakeProfile(makeProfileData(rank))
			seeded[userId] = true
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile
		end

		afterEach(function()
			PlayerDataService.mutate = realMutate
			RankService:_setPersist(nil)
			RankService:_setSeason(nil)
			for userId in seeded do
				RankService:forget(userId)
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
				StateSyncPublicPlayerStore.remove(userId)
			end
			seeded = {}
		end)

		it("pays a shift into the profile once per run and publishes the XP", function()
			local profile = seed(901)
			RankService:load(901)
			local ok, award = RankService:awardShift(901, "srv:1", facts())
			expect(ok).to.equal(true)
			expect(award.total).to.equal(10 + 15 + 4 + 5 + 5)
			expect(profile.Data.account.rank.xp).to.equal(39)
			expect(profile.Data.account.rank.lastAwardedRunId).to.equal("srv:1")
			expect(publicXp(901)).to.equal(39)
			local again = RankService:awardShift(901, "srv:1", facts())
			expect(again).to.equal(false)
			expect(profile.Data.account.rank.xp).to.equal(39)
		end)

		it("writes nothing for a run already paid: no mutate, so no save and no audit line", function()
			local profile = seed(910)
			RankService:load(910)
			RankService:awardShift(910, "srv:1", facts())
			local calls = spyRankMutates()
			local ok = RankService:awardShift(910, "srv:1", facts())
			expect(ok).to.equal(false)
			expect(calls.count).to.equal(0)
			expect(profile.Data.account.rank.xp).to.equal(39)
			expect(RankService:awardShift(910, "srv:2", facts())).to.equal(true)
			expect(calls.count).to.equal(1)
		end)

		it("writes nothing when a profile loads with a rank already in the current season", function()
			seed(911)
			local calls = spyRankMutates()
			expect(RankService:load(911)).to.equal(true)
			expect(calls.count).to.equal(0)
			expect(publicXp(911)).to.equal(0)
		end)

		it("levels up from 1 to 2 when the XP crosses the threshold", function()
			seed(902)
			RankService:load(902)
			expect(RankService:progressOf(902).level.level).to.equal(1)
			RankService:awardShift(902, "srv:1", facts())
			RankService:awardShift(902, "srv:2", facts({ items = 0, crewExtracted = false }))
			local progress = RankService:progressOf(902)
			expect(progress.xp).to.equal(39 + 30)
			expect(progress.level.level).to.equal(2)
		end)

		it("resets a rank from another season to level 1 on load", function()
			local profile = seed(903, { season = "old-season", xp = 500, lastAwardedRunId = "x:1" })
			RankService:load(903)
			expect(profile.Data.account.rank.season).to.equal(RankConstants.RANK_SEASON)
			expect(profile.Data.account.rank.xp).to.equal(0)
			expect(publicXp(903)).to.equal(0)
		end)

		it("wipes everyone's rank on their next load when the season is bumped", function()
			local profile = seed(904)
			RankService:load(904)
			RankService:awardShift(904, "srv:1", facts())
			expect(profile.Data.account.rank.xp > 0).to.equal(true)
			RankService:_setSeason("spec-next-season")
			RankService:load(904)
			expect(profile.Data.account.rank.xp).to.equal(0)
			expect(profile.Data.account.rank.season).to.equal("spec-next-season")
		end)

		it("keeps a session-only rank in memory and never writes the profile", function()
			RankService:_setPersist(false)
			local profile = seed(905, { season = RankConstants.RANK_SEASON, xp = 77, lastAwardedRunId = "" })
			RankService:load(905)
			expect(RankService:get(905).xp).to.equal(0)
			local ok = RankService:awardShift(905, "srv:1", facts())
			expect(ok).to.equal(true)
			expect(RankService:get(905).xp).to.equal(39)
			expect(publicXp(905)).to.equal(39)
			expect(profile.Data.account.rank.xp).to.equal(77)
			expect(RankService:awardShift(905, "srv:1", facts())).to.equal(false)
		end)

		it("refuses an award for a player whose rank is not loaded", function()
			expect(RankService:awardShift(906, "srv:1", facts())).to.equal(false)
		end)

		it("pays nothing (but succeeds) for a zero award, never moving the run guard backwards", function()
			local profile = seed(907)
			RankService:load(907)
			local ok, award = RankService:awardShift(907, "srv:1", facts({ worked = false }))
			expect(ok).to.equal(false)
			expect(award.total).to.equal(0)
			expect(profile.Data.account.rank.lastAwardedRunId).to.equal("")
		end)

		it("resets a player's rank to level 1 (admin)", function()
			local profile = seed(908)
			RankService:load(908)
			RankService:awardShift(908, "srv:1", facts())
			expect(RankService:reset(908)).to.equal(true)
			expect(profile.Data.account.rank.xp).to.equal(0)
			expect(publicXp(908)).to.equal(0)
		end)

		it("announces every published rank on `changed` (load, award, reset), with the player's id", function()
			seed(909)
			local heard = {}
			local connection = RankService.changed:Connect(function(userId)
				table.insert(heard, userId)
			end)
			RankService:load(909)
			RankService:awardShift(909, "srv:1", facts())
			RankService:awardShift(909, "srv:1", facts())
			RankService:reset(909)
			connection:Disconnect()
			expect(#heard).to.equal(3)
			for _, userId in heard do
				expect(userId).to.equal(909)
			end
		end)
	end)
end
