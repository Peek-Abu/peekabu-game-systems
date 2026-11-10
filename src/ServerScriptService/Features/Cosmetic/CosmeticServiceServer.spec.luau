--[[
	Unit tests for CosmeticServiceServer: real fake profiles through `_setProfileForTesting` and the real
	mutate()/transaction() and validator machinery (the TitleServiceServer.spec strategy). The shift phase is stubbed
	on ShiftServiceServer and restored after each test.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local EntitlementServiceServer = require(ServerScriptService.Features.Entitlement.EntitlementServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local CosmeticService = require(ServerScriptService.Features.Cosmetic.CosmeticServiceServer)
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
			premium = { balance = 0 },
			receipts = { ids = {} },
			firstSeen = { at = 0 },
			loadout = { current = "Pippa", picked = false, looks = {}, stickers = { "", "", "", "" }, seen = {} },
			entitlements = { owned = {} },
			settings = { values = {} },
			dailyReward = { lastDay = 0, streak = 0 },
			rank = { season = "mvp-1", xp = 0, lastAwardedRunId = "" },
			titles = { earned = {} },
			coffee = { seconds = 0, since = 0 },
			deals = { bought = {}, picks = {} },
		},
		slots = slots,
	}
end

return function()
	describe("CosmeticServiceServer", function()
		local seeded = {}
		local realGetShift = ShiftServiceServer.getShift
		local phase = "lobby"
		local fired = 0
		local connection

		-- `changed` is a SignalPlus signal: handlers run deferred (next resumption point), so count after a yield.
		local function settle()
			task.wait()
		end

		local function seed(userId)
			PlayerDataService:_setProfileForTesting(userId, makeFakeProfile(makeProfileData()))
			seeded[userId] = true
		end

		beforeEach(function()
			phase = "lobby"
			fired = 0
			ShiftServiceServer.getShift = function()
				return { phase = phase }
			end
			connection = CosmeticService.changed:Connect(function()
				fired += 1
			end)
		end)

		afterEach(function()
			settle()
			connection:Disconnect()
			ShiftServiceServer.getShift = realGetShift
			for userId in seeded do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
			end
			seeded = {}
		end)

		it("reads a fresh profile as Pippa in her defaults, and nil when unloaded", function()
			seed(1)
			expect(CosmeticService:currentEmployee(1)).to.equal("Pippa")
			local look = CosmeticService:lookOf(1)
			expect(look.skin).to.equal("Pippa.Default")
			expect(look.idle).to.equal("Pippa.Classic")
			expect(CosmeticService:getLoadout(999)).to.equal(nil)
			expect(CosmeticService:lookOf(999)).to.equal(nil)
		end)

		it("reads the whole outfit (employee, look, vacuum, stickers) and equips a vacuum", function()
			seed(1)
			local outfit = CosmeticService:outfitOf(1)
			expect(outfit.employee).to.equal("Pippa")
			expect(outfit.vacuum).to.equal("Vacuum.StandardIssue")
			expect(CosmeticService:outfitOf(999)).to.equal(nil)
			expect(CosmeticService:equip(1, { kind = "vacuum", id = "Vacuum.BrassBellows" })).to.equal(false)
			CosmeticService:grant(1, "Vacuum.BrassBellows")
			expect(CosmeticService:equip(1, { kind = "vacuum", id = "Vacuum.BrassBellows" })).to.equal(true)
			expect(CosmeticService:outfitOf(1).vacuum).to.equal("Vacuum.BrassBellows")
		end)

		it("grants a bundle in one go, and a second grant changes nothing", function()
			seed(1)
			expect(CosmeticService:owns(1, "Cappy.PJ")).to.equal(false)
			expect(CosmeticService:grant(1, "Cappy.PJ")).to.equal(true)
			for _, id in { "Cappy.PJ", "Cappy.CocoaSip", "CozyPack", "CozyPack.CocoaBreak" } do
				expect(CosmeticService:owns(1, id)).to.equal(true)
			end
			settle()
			expect(fired).to.equal(1)
			local ok, reason = CosmeticService:grant(1, "Cappy.PJ")
			expect(ok).to.equal(false)
			expect(reason).to.equal("already owned")
			settle()
			expect(fired).to.equal(1)
		end)

		it("equips an owned skin, saves it and fires changed", function()
			seed(1)
			CosmeticService:grant(1, "Cappy")
			CosmeticService:grant(1, "Cappy.PJ")
			settle()
			fired = 0
			expect(CosmeticService:equip(1, { kind = "employee", id = "Cappy" })).to.equal(true)
			expect(CosmeticService:equip(1, { kind = "skin", id = "Cappy.PJ", style = 2 })).to.equal(true)
			expect(CosmeticService:currentEmployee(1)).to.equal("Cappy")
			local look = CosmeticService:lookOf(1)
			expect(look.skin).to.equal("Cappy.PJ")
			expect(look.style).to.equal(2)
			expect(CosmeticService:getLoadout(1).looks.Cappy.skin).to.equal("Cappy.PJ")
			settle()
			expect(fired).to.equal(2)
		end)

		it("refuses every change during a shift", function()
			seed(1)
			CosmeticService:grant(1, "Cappy")
			for _, running in { "starting", "running", "results" } do
				phase = running
				local ok, reason = CosmeticService:equip(1, { kind = "employee", id = "Cappy" })
				expect(ok).to.equal(false)
				expect(reason).to.equal("locked during a shift")
				expect(CosmeticService:isLocked()).to.equal(true)
			end
			expect(CosmeticService:currentEmployee(1)).to.equal("Pippa")
		end)

		it("refuses unowned and wrong-employee changes with the rule's reason", function()
			seed(1)
			local ok, reason = CosmeticService:equip(1, { kind = "skin", id = "Cappy.PJ", style = 1 })
			expect(ok).to.equal(false)
			expect(reason).to.equal("not owned")
			local _, wrong = CosmeticService:equip(1, { kind = "idle", employee = "Cappy", id = "Pippa.Classic" })
			expect(wrong).to.equal("wrong employee")
			settle()
			expect(fired).to.equal(0)
		end)

		it("lets the first-join pick happen once, of an owned employee", function()
			seed(1)
			local _, notOwned = CosmeticService:pick(1, "Cappy")
			expect(notOwned).to.equal("not owned")
			CosmeticService:grant(1, "Cappy")
			expect(CosmeticService:pick(1, "Cappy")).to.equal(true)
			expect(CosmeticService:getLoadout(1).picked).to.equal(true)
			expect(CosmeticService:currentEmployee(1)).to.equal("Cappy")
			local ok, reason = CosmeticService:pick(1, "Pippa")
			expect(ok).to.equal(false)
			expect(reason).to.equal("already picked")
		end)

		it("falls back to the default skin when the worn one is no longer owned", function()
			seed(1)
			CosmeticService:grant(1, "Cappy.PJ")
			CosmeticService:equip(1, { kind = "skin", id = "Cappy.PJ", style = 3 })
			EntitlementServiceServer:revoke(1, "skin", "Cappy.PJ")
			expect(CosmeticService:lookOf(1, "Cappy").skin).to.equal("Cappy.Default")
		end)

		it("hands grant ops to a transaction (a purchase and its unlock in one write)", function()
			seed(1)
			local ok = PlayerDataService:transaction(CosmeticService:grantOps(1, "Prickles.Sheriff"))
			expect(ok).to.equal(true)
			expect(CosmeticService:owns(1, "Prickles.Lasso")).to.equal(true)
			expect(CosmeticService:owns(1, "SheriffPack")).to.equal(true)
		end)

		it("announces grants and the first-join pick (the client plays a reveal)", function()
			seed(1)
			local events = {}
			local listening = CosmeticService.granted:Connect(function(event)
				table.insert(events, event)
			end)
			CosmeticService:grant(1, "Cappy")
			CosmeticService:pick(1, "Pippa")
			settle()
			listening:Disconnect()
			expect(#events).to.equal(2)
			expect(events[1].ids[1]).to.equal("Cappy")
			expect(events[1].source).to.equal("grant")
			expect(events[2].ids[1]).to.equal("Pippa")
			expect(events[2].source).to.equal("pick")
		end)

		describe("requests (trust boundary)", function()
			local fakePlayer = { UserId = 1, Name = "TestPlayer" }

			it("equips from a well-formed request and drops a malformed one", function()
				seed(1)
				CosmeticService:grant(1, "Cappy")
				CosmeticService._onEquipRequest({ kind = "employee", id = 7 }, fakePlayer)
				CosmeticService._onEquipRequest(nil, fakePlayer)
				expect(CosmeticService:currentEmployee(1)).to.equal("Pippa")
				CosmeticService._onEquipRequest({ kind = "employee", id = "Cappy" }, fakePlayer)
				expect(CosmeticService:currentEmployee(1)).to.equal("Cappy")
			end)

			it("marks owned items seen from a request, dropping malformed ones and items not owned", function()
				seed(1)
				CosmeticService:grant(1, "Cappy")
				expect(function()
					CosmeticService._onSeenRequest({ ids = "Cappy" }, fakePlayer)
					CosmeticService._onSeenRequest(nil, fakePlayer)
				end).never.to.throw()
				expect(CosmeticService:getLoadout(1).seen.Cappy).to.equal(nil)
				CosmeticService._onSeenRequest({ ids = { "Cappy", "Prickles" } }, fakePlayer)
				expect(CosmeticService:getLoadout(1).seen.Cappy).to.equal(true)
				expect(CosmeticService:getLoadout(1).seen.Prickles).to.equal(nil)
				local ok, reason = CosmeticService:markSeen(1, { "Cappy" })
				expect(ok).to.equal(false)
				expect(reason).to.equal("nothing new")
			end)

			it("picks from a well-formed request, never throwing on a bad one", function()
				seed(1)
				expect(function()
					CosmeticService._onPickRequest({ employee = 3 }, fakePlayer)
					CosmeticService._onPickRequest({ employee = "Nobody" }, fakePlayer)
				end).never.to.throw()
				expect(CosmeticService:getLoadout(1).picked).to.equal(false)
				CosmeticService._onPickRequest({ employee = "Pippa" }, fakePlayer)
				expect(CosmeticService:getLoadout(1).picked).to.equal(true)
			end)
		end)
	end)
end
