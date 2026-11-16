--[[
	Unit tests for EventServiceServer: real fake profiles through `_setProfileForTesting` and the real transaction
	machinery, with the clock, the admin preview, the friend check and the Paid packet stubbed through `_setDeps`.
	Only fake user ids (900001+) are used; no real account is ever touched.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local sift = require(ReplicatedStorage.Packages.sift)
local EventRegistry = require(ReplicatedStorage.Shared.Features.Event.Data.EventRegistry)
local EventUtils = require(ReplicatedStorage.Shared.Features.Event.Utils.EventUtils)
local DailyRewardConstants = require(ReplicatedStorage.Shared.Features.DailyReward.Data.DailyRewardConstants)
local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local CurrencyService = require(ServerScriptService.Features.Currency.CurrencyServiceServer)
local EventService = require(ServerScriptService.Features.Event.EventServiceServer)

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

local function makeProfileData(acorns, credits, day)
	local slots = {}
	for index = 1, PlayerDataConstants.MAX_SLOTS do
		slots[index] = {
			currency = { credits = credits or 0, gloom = 0, acorns = acorns or 0 },
			inventory = { items = {} },
			equippedTitle = {},
		}
	end
	return {
		_schemaVersion = PlayerDataMigrationSystem.CURRENT_VERSION,
		slotState = { active = 1, epoch = 1 },
		account = {
			itemMint = { nextUid = 1 },
			premium = { balance = 0 },
			receipts = { ids = {} },
			firstSeen = { at = 0 },
			loadout = { current = "Pippa", picked = true, looks = {}, stickers = { "", "", "", "" }, seen = {} },
			lockers = { keys = {}, pity = {}, opened = 0 },
			entitlements = { owned = {} },
			settings = { values = {} },
			dailyReward = { lastDay = 0, streak = 0 },
			rank = { season = "mvp-1", xp = 0, lastAwardedRunId = "" },
			titles = { earned = {} },
			coffee = { seconds = 0, since = 0 },
			deals = { bought = {}, picks = {} },
			places = { owned = {} },
			events = { day = day or 0 },
		},
		slots = slots,
	}
end

return function()
	describe("EventServiceServer", function()
		local HARVEST = EventRegistry.get("harvest")
		local DURING = HARVEST.starts + 3600
		local AFTER = HARVEST.ends + 3600
		local A, B, C = 900001, 900002, 900003
		local seeded = {}
		local clock, preview, friends, sent

		local function seed(userId, acorns, credits, day)
			PlayerDataService:_setProfileForTesting(userId, makeFakeProfile(makeProfileData(acorns, credits, day)))
			seeded[userId] = true
		end

		local function acorns(userId)
			return CurrencyService:getCurrencyAmount(userId, "acorns")
		end

		beforeEach(function()
			clock = DURING
			preview = nil
			friends = {}
			sent = {}
			EventService._setDeps({
				now = function()
					return clock
				end,
				preview = function()
					return preview
				end,
				isFriend = function(a, b)
					return friends[`{a}:{b}`] == true or friends[`{b}:{a}`] == true
				end,
				sendPaid = function(userId, payload)
					table.insert(sent, { userId = userId, payload = payload })
				end,
			})
		end)

		afterEach(function()
			EventService._setDeps(nil)
			for userId in seeded do
				PlayerDataService:_setProfileForTesting(userId, nil)
			end
			table.clear(seeded)
		end)

		describe("live", function()
			it("is the event whose dates hold, else nil", function()
				expect(EventService:live()).to.equal(HARVEST)
				clock = HARVEST.starts - 1
				expect(EventService:live()).to.equal(nil)
				clock = AFTER
				expect(EventService:live()).to.equal(nil)
			end)

			it("shows a previewed event at any time", function()
				clock = HARVEST.starts - 10 * 86400
				preview = "harvest"
				expect(EventService:live()).to.equal(HARVEST)
			end)
		end)

		describe("payShift", function()
			it(
				"pays the base, the contract and the day's first shift, then no first-shift bonus again that day",
				function()
					seed(A, 0, 0, 0)
					expect(EventService:payShift(A, HARVEST, { quotaMet = true }, { A })).to.equal(true)
					expect(acorns(A)).to.equal(40)
					expect(sent[1].userId).to.equal(A)
					expect(sent[1].payload.total).to.equal(40)
					expect(table.concat(sent[1].payload.parts, ",")).to.equal("finished,contract,firstToday")

					expect(EventService:payShift(A, HARVEST, { quotaMet = false }, { A })).to.equal(true)
					expect(acorns(A)).to.equal(50)
				end
			)

			it("pays the first-shift bonus again the next day", function()
				local today = EventUtils.day(DURING, DailyRewardConstants.DAY_OFFSET_HOURS)
				seed(A, 0, 0, today - 1)
				EventService:payShift(A, HARVEST, { quotaMet = false }, { A })
				expect(acorns(A)).to.equal(30)
			end)

			it("adds the friend bonus only when a Roblox friend is in the crew", function()
				local today = EventUtils.day(DURING, DailyRewardConstants.DAY_OFFSET_HOURS)
				seed(A, 0, 0, today)
				seed(B, 0, 0, today)
				friends[`{A}:{C}`] = true
				EventService:payShift(A, HARVEST, { quotaMet = false }, { A, B })
				expect(acorns(A)).to.equal(10)
				EventService:payShift(A, HARVEST, { quotaMet = false }, { A, B, C })
				expect(acorns(A)).to.equal(25)
			end)

			it("refuses (to retry) when the profile is not loaded", function()
				expect(EventService:payShift(A, HARVEST, { quotaMet = true }, { A })).to.equal(false)
				expect(#sent).to.equal(0)
			end)
		end)

		describe("convertLeftover", function()
			it("turns leftover acorns into Credits once the event has ended", function()
				clock = AFTER
				seed(A, 37, 100)
				expect(EventService:convertLeftover(A)).to.equal(true)
				expect(acorns(A)).to.equal(0)
				expect(CurrencyService:getCurrencyAmount(A, "credits")).to.equal(100 + 37 * HARVEST.convertRate)
				expect(EventService:convertLeftover(A)).to.equal(false)
			end)

			it("keeps acorns while the event is live, or before any event has ended", function()
				seed(A, 37, 0)
				expect(EventService:convertLeftover(A)).to.equal(false)
				clock = HARVEST.starts - 1
				expect(EventService:convertLeftover(A)).to.equal(false)
				expect(acorns(A)).to.equal(37)
			end)

			it("keeps acorns during an admin preview", function()
				clock = AFTER
				preview = "harvest"
				seed(A, 37, 0)
				expect(EventService:convertLeftover(A)).to.equal(false)
			end)
		end)
	end)
end
