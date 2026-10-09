--[[
	Unit tests for EntitlementServiceServer. Same strategy as the Title spec: seed REAL fake profiles via
	`_setProfileForTesting` and drive the REAL mutate()/transaction()/validator machinery.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local EntitlementService = require(ServerScriptService.Features.Entitlement.EntitlementServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local EntitlementRegistry = require(ReplicatedStorage.Shared.Features.Entitlement.Data.EntitlementRegistry)
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
		},
		slots = slots,
	}
end

return function()
	describe("EntitlementServiceServer", function()
		local seeded = {}

		beforeAll(function()
			if not EntitlementRegistry.has("spec-suit", "hazmat") then
				EntitlementRegistry.register("spec-suit", "hazmat", { name = "Hazmat" })
			end
			if not EntitlementRegistry.has("spec-suit", "diver") then
				EntitlementRegistry.register("spec-suit", "diver", { name = "Diver" })
			end
		end)

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

		it("grants once, reports ownership and lists the category", function()
			seed(1)
			expect(EntitlementService:owns(1, "spec-suit", "hazmat")).to.equal(false)
			expect(EntitlementService:grant(1, "spec-suit", "hazmat")).to.equal(true)
			local ok, reason = EntitlementService:grant(1, "spec-suit", "hazmat")
			expect(ok).to.equal(false)
			expect(reason).to.equal("already owned")
			expect(EntitlementService:owns(1, "spec-suit", "hazmat")).to.equal(true)
			expect(EntitlementService:ownedIn(1, "spec-suit")[1]).to.equal("hazmat")
		end)

		it("fires granted for a new grant only", function()
			seed(1)
			local fired = 0
			local connection = EntitlementService.granted:Connect(function(userId, category, id)
				if userId == 1 and category == "spec-suit" and id == "diver" then
					fired += 1
				end
			end)
			EntitlementService:grant(1, "spec-suit", "diver")
			EntitlementService:grant(1, "spec-suit", "diver")
			task.wait()
			connection:Disconnect()
			expect(fired).to.equal(1)
		end)

		it("revokes", function()
			seed(1)
			EntitlementService:grant(1, "spec-suit", "hazmat")
			expect(EntitlementService:revoke(1, "spec-suit", "hazmat")).to.equal(true)
			expect(EntitlementService:owns(1, "spec-suit", "hazmat")).to.equal(false)
			expect((EntitlementService:revoke(1, "spec-suit", "hazmat"))).to.equal(false)
		end)

		it("throws for an unregistered entitlement", function()
			seed(1)
			expect(function()
				EntitlementService:grant(1, "spec-suit", "never-registered")
			end).to.throw()
			expect(function()
				EntitlementService:grantOp(1, "spec-suit", "never-registered")
			end).to.throw()
		end)

		it("reports an unloaded profile", function()
			local ok, reason = EntitlementService:grant(999, "spec-suit", "hazmat")
			expect(ok).to.equal(false)
			expect(reason).to.equal("profile not loaded")
			expect(EntitlementService:owns(999, "spec-suit", "hazmat")).to.equal(false)
			expect(#EntitlementService:ownedIn(999, "spec-suit")).to.equal(0)
		end)

		it("grants inside a transaction, and an already-owned grant does not abort it", function()
			seed(1)
			EntitlementService:grant(1, "spec-suit", "hazmat")
			local committed = PlayerDataService:transaction({
				EntitlementService:grantOp(1, "spec-suit", "hazmat"),
				EntitlementService:grantOp(1, "spec-suit", "diver"),
			})
			expect(committed).to.equal(true)
			expect(EntitlementService:owns(1, "spec-suit", "diver")).to.equal(true)
		end)

		it("refuses a malformed write from any path (the data-layer validator)", function()
			seed(1)
			local committed = PlayerDataService:transaction({
				{
					userId = 1,
					path = "account.entitlements",
					mutator = function(entitlements)
						entitlements.owned["spec-suit"] = { hazmat = "yes" }
						return true
					end,
				},
			})
			expect(committed).to.equal(false)
			expect(EntitlementService:owns(1, "spec-suit", "hazmat")).to.equal(false)
		end)
	end)
end
