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
local Service = require(ServerScriptService.Features.WorkOrder.WorkOrderServiceServer)
local Registry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local sift = require(ReplicatedStorage.Packages.sift)

local MONDAY = 1792972800

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
			firstSeen = { at = 0 },
			loadout = { current = "Pippa", picked = false, looks = {}, stickers = { "", "", "", "" }, seen = {} },
			entitlements = { owned = {} },
			settings = { values = {} },
			dailyReward = { lastDay = 0, streak = 0 },
			timecard = { week = 0, punched = {}, weeks = 0 },
			workOrder = { day = 0, progress = 0, claimed = false },
			rank = { season = "mvp-1", xp = 0, lastAwardedRunId = "" },
		},
		slots = slots,
	}
end

return function()
	describe("WorkOrderServiceServer", function()
		local profile
		local now = MONDAY
		local player = { UserId = 841, Name = "WorkOrderSpec" }
		beforeEach(function()
			profile = makeFakeProfile(makeProfileData())
			PlayerDataService:_setProfileForTesting(841, profile)
			now = MONDAY
			Service:_setClock(function()
				return now
			end)
		end)
		afterEach(function()
			Service:_setClock(nil)
			PlayerDataService:_setProfileForTesting(841, nil)
			StateSyncServerStore.remove(841)
		end)
		it("counts only today's matching real server counter and pays once at target", function()
			local order = Registry.orderFor(now)
			expect(Service:record(player, order.kind, order.target - 1)).to.equal(true)
			expect(profile.Data.account.workOrder.claimed).to.equal(false)
			expect(Service:record(player, order.kind, 1)).to.equal(true)
			local paid = profile.Data.slots[1].currency.credits
			expect(paid > 0).to.equal(true)
			expect(profile.Data.account.workOrder.claimed).to.equal(true)
			expect(Service:record(player, order.kind, 100)).to.equal(false)
			expect(profile.Data.slots[1].currency.credits).to.equal(paid)
		end)
		it("pays each gameplay counter through the real shift adapter exactly once", function()
			local Adapter = require(ServerScriptService.Features.Shift.Systems.ShiftWorkOrderSystem)
			local member = { UserId = 841, Name = "WorkOrderSpec", Parent = workspace }
			for _, kind in { "piles", "cargo", "salvage", "shifts" } do
				now = MONDAY - 14 * 86400 -- bounded legacy catalog covers overtime before the pacing cutoff
				local searches = 0
				while Registry.orderFor(now).kind ~= kind and searches < 5 do
					searches += 1
					now += 86400
				end
				local order = Registry.orderFor(now)
				local source = {
					piles = fakeSignal(),
					loaded = fakeSignal(),
					changed = fakeSignal(),
					eligible = function()
						return true
					end,
					crew = function()
						return { member }
					end,
				}
				local stop = Adapter.start(source, function(p, counter, amount)
					Service:record(p, counter, amount)
				end)
				local before = profile.Data.slots[1].currency.credits or 0
				if kind == "piles" then
					for _ = 1, order.target do
						source.piles:Fire(nil, { member, member })
					end
				elseif kind == "cargo" then
					source.loaded:Fire(member, order.target, 0, 0)
				elseif kind == "salvage" then
					source.loaded:Fire(member, order.target, order.target, order.target)
				else
					for run = 1, order.target do
						source.changed:Fire({ phase = "results", shift = run })
						source.changed:Fire({ phase = "results", shift = run })
					end
				end
				expect(profile.Data.account.workOrder.claimed).to.equal(true)
				expect(profile.Data.account.workOrder.progress).to.equal(order.target)
				expect(profile.Data.slots[1].currency.credits).to.equal(before + Registry.REWARD_CREDITS)
				stop()
				now += 86400
			end
		end)
		it("rejects invalid amounts and unrelated counters", function()
			local order = Registry.orderFor(now)
			local other = if order.kind == "piles" then "cargo" else "piles"
			expect(Service:record(player, other, 1)).to.equal(false)
			expect(Service:record(player, order.kind, math.huge)).to.equal(false)
			expect(Service:record(player, order.kind, 0 / 0)).to.equal(false)
			expect(Service:record(player, order.kind, -1)).to.equal(false)
		end)
		it("rolls yesterday on first progress and starts at zero", function()
			profile.Data.account.workOrder = { day = Registry.dayIndex(now) - 1, progress = 1, claimed = false }
			expect(Service:record(player, Registry.orderFor(now).kind, 1)).to.equal(true)
			expect(profile.Data.account.workOrder.progress).to.equal(1)
			expect(profile.Data.account.workOrder.day).to.equal(Registry.dayIndex(now))
		end)
		it("rolls back completion when the reward wallet is invalid", function()
			local order = Registry.orderFor(now)
			profile.Data.slots[1].currency.credits = math.huge
			expect(Service:record(player, order.kind, order.target)).to.equal(false)
			expect(profile.Data.account.workOrder.claimed).to.equal(false)
			expect(profile.Data.account.workOrder.progress).to.equal(0)
		end)
	end)
end
