--[[
	Unit tests for TimecardServiceServer. Same strategy as the DailyReward spec: seed REAL fake profiles via
	`_setProfileForTesting` and drive the REAL mutate()/transaction()/validator machinery, with the clock pinned to
	Monday 26 Oct 2026 00:00 UTC.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local TimecardService = require(ServerScriptService.Features.Timecard.TimecardServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local sift = require(ReplicatedStorage.Packages.sift)

local MONDAY = 1792972800
local DAY = 86400
local WEEK = 7 * DAY

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
			coffee = { seconds = 0, since = 0 },
			deals = { bought = {}, picks = {} },
			places = { owned = {} },
			premium = { balance = 0 },
			receipts = { ids = {} },
			firstSeen = { at = 0 },
			loadout = { current = "Pippa", picked = false, looks = {}, stickers = { "", "", "", "" }, seen = {} },
			entitlements = { owned = {} },
			settings = { values = {} },
			dailyReward = { lastDay = 0, streak = 0 },
			timecard = { week = 0, punched = {}, weeks = 0 },
			lockers = { keys = {}, pity = {}, opened = 0 },
			social = { groupPaid = false, referredBy = 0, referralPaid = false, referrals = 0, askedAt = 0 },
			training = { finished = false, runs = 0, toured = false },
			workOrder = { day = 0, progress = 0, claimed = false },
			rank = { season = "mvp-1", xp = 0, lastAwardedRunId = "" },
		},
		slots = slots,
	}
end

return function()
	describe("TimecardServiceServer", function()
		local seeded = {}
		local now = MONDAY

		local function seed(userId)
			local profile = makeFakeProfile(makeProfileData())
			seeded[userId] = true
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile, { UserId = userId, Name = `Spec{userId}` }
		end

		beforeEach(function()
			TimecardService:setCanPunch(function()
				return true
			end)
			now = MONDAY
			TimecardService:_setClock(function()
				return now
			end)
		end)

		afterEach(function()
			TimecardService:_setClock(nil)
			TimecardService:setCanPunch(nil)
			TimecardService:setPayout(nil)
			for userId in seeded do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
			end
			seeded = {}
		end)

		it("grants actual default milestone balances once with the punch", function()
			local profile, player = seed(1)
			TimecardService:setPayout(nil)
			profile.Data.account.timecard = { week = MONDAY, punched = { 1, 2 }, weeks = 0 }
			now = MONDAY + 2 * DAY
			expect(TimecardService:punch(player)).to.equal(true)
			expect(profile.Data.account.lockers.keys.gloom).to.equal(1)
			expect(TimecardService:punch(player)).to.equal(false)
			expect(profile.Data.account.lockers.keys.gloom).to.equal(1)
			profile.Data.account.timecard = { week = MONDAY, punched = { 1, 2, 3, 4 }, weeks = 3 }
			now = MONDAY + 4 * DAY
			expect(TimecardService:punch(player)).to.equal(true)
			expect(profile.Data.account.premium.balance).to.equal(5)
			expect(profile.Data.slots[1].currency.credits).to.equal(500)
		end)

		it("rolls back the fifth punch and paycheck if the Gleam grant is invalid", function()
			local profile, player = seed(1)
			profile.Data.account.timecard = { week = MONDAY, punched = { 1, 2, 3, 4 }, weeks = 3 }
			profile.Data.account.premium.balance = math.huge
			now = MONDAY + 4 * DAY
			expect(TimecardService:punch(player)).to.equal(false)
			expect(#profile.Data.account.timecard.punched).to.equal(4)
			expect(profile.Data.account.timecard.weeks).to.equal(3)
			expect(profile.Data.slots[1].currency.credits or 0).to.equal(0)
		end)

		it("fails closed until the hub gate approves the player", function()
			local profile, player = seed(1)
			TimecardService:setCanPunch(nil)
			expect(TimecardService:punch(player)).to.equal(false)
			expect(#profile.Data.account.timecard.punched).to.equal(0)
			TimecardService:setCanPunch(function()
				return false
			end)
			expect(TimecardService:punch(player)).to.equal(false)
			TimecardService:setCanPunch(function()
				return true
			end)
			expect(TimecardService:punch(player)).to.equal(true)
		end)

		it("punches a day once, then refuses until tomorrow", function()
			local profile, player = seed(1)
			expect(TimecardService:status(player).canPunch).to.equal(true)
			expect(TimecardService:punch(player)).to.equal(true)
			expect(#profile.Data.account.timecard.punched).to.equal(1)
			expect(profile.Data.account.timecard.punched[1]).to.equal(1)
			expect(profile.Data.account.timecard.week).to.equal(MONDAY)

			local ok, reason = TimecardService:punch(player)
			expect(ok).to.equal(false)
			expect(reason).to.equal("already punched today")

			now += DAY
			expect(TimecardService:punch(player)).to.equal(true)
			expect(#profile.Data.account.timecard.punched).to.equal(2)
		end)

		it("pays the key on the third punch and the stars on the fifth", function()
			local _, player = seed(1)
			local paid = {}
			TimecardService:setPayout(function(_player, result)
				table.insert(paid, result.milestone or "none")
				return {}
			end)
			-- Monday, Tuesday, Wednesday: the third punch lands the key.
			for _ = 1, 3 do
				expect(TimecardService:punch(player)).to.equal(true)
				now += DAY
			end
			expect(paid[1]).to.equal("none")
			expect(paid[2]).to.equal("none")
			expect(paid[3]).to.equal("key")
			-- Thursday pays nothing; Friday's fifth punch fills the card and pays the stars.
			expect(TimecardService:punch(player)).to.equal(true)
			now += DAY
			expect(TimecardService:punch(player)).to.equal(true)
			expect(paid[4]).to.equal("none")
			expect(paid[5]).to.equal("stars")
		end)

		it("pays the paycheque on the fourth consecutive filled week", function()
			local profile, player = seed(1)
			profile.Data.account.timecard = { week = MONDAY, punched = { 1, 2, 3, 4 }, weeks = 3 }
			now = MONDAY + 4 * DAY
			local paychecks = 0
			TimecardService:setPayout(function(_player, result)
				if result.paycheck then
					paychecks += 1
				end
				return {}
			end)
			expect(TimecardService:punch(player)).to.equal(true)
			expect(paychecks).to.equal(1)
			expect(profile.Data.account.timecard.weeks).to.equal(4)
		end)

		it("commits the payout with the punch", function()
			local profile, player = seed(1)
			TimecardService:setPayout(function(_player, result)
				if result.milestone then
					return {
						{
							userId = 1,
							path = "account.titles",
							mutator = function(titles)
								titles.earned[`spec-{result.milestone}`] = true
								return true
							end,
						},
					}
				end
				return {}
			end)
			profile.Data.account.timecard = { week = MONDAY, punched = { 1, 2 }, weeks = 0 }
			now += 2 * DAY
			expect(TimecardService:punch(player)).to.equal(true)
			expect(profile.Data.account.titles.earned["spec-key"]).to.equal(true)
			expect(#profile.Data.account.timecard.punched).to.equal(3)
		end)

		it("records nothing when the payout cannot be granted", function()
			local profile, player = seed(1)
			TimecardService:setPayout(function()
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
			expect((TimecardService:punch(player))).to.equal(false)
			expect(#profile.Data.account.timecard.punched).to.equal(0)
			expect(profile.Data.account.timecard.week).to.equal(0)
		end)

		it("rolls a stored card forward to this week, keeping a completed run", function()
			local profile, _player = seed(1)
			profile.Data.account.timecard = { week = MONDAY - WEEK, punched = { 1, 2, 3, 4, 5 }, weeks = 2 }
			expect(TimecardService:roll(1)).to.equal(true)
			expect(profile.Data.account.timecard.week).to.equal(MONDAY)
			expect(#profile.Data.account.timecard.punched).to.equal(0)
			expect(profile.Data.account.timecard.weeks).to.equal(2)
			-- Already on this week: nothing to write.
			expect(TimecardService:roll(1)).to.equal(false)
		end)

		it("rolls the card over inside the punch", function()
			local profile, player = seed(1)
			profile.Data.account.timecard = { week = MONDAY - WEEK, punched = { 1, 2, 3, 4, 5 }, weeks = 1 }
			expect(TimecardService:punch(player)).to.equal(true)
			local card = profile.Data.account.timecard
			expect(card.week).to.equal(MONDAY)
			expect(#card.punched).to.equal(1)
			expect(card.weeks).to.equal(1)
		end)

		it("reports an unloaded profile and resets a card", function()
			local ok, reason = TimecardService:punch({ UserId = 999, Name = "Nobody" })
			expect(ok).to.equal(false)
			expect(reason).to.equal("profile not loaded")
			local profile, player = seed(1)
			TimecardService:punch(player)
			expect(TimecardService:reset(1)).to.equal(true)
			expect(profile.Data.account.timecard.week).to.equal(0)
			expect(#profile.Data.account.timecard.punched).to.equal(0)
		end)
	end)
end
