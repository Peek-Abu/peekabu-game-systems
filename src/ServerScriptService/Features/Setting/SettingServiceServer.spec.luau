--[[
	Unit tests for SettingServiceServer. Same strategy as the Title spec: seed REAL fake profiles via
	`_setProfileForTesting` and drive the REAL mutate()/validator machinery. The request path is driven
	through the `_onRequest` test seam (no ByteNet).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local SettingService = require(ServerScriptService.Features.Setting.SettingServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local SettingRules = require(ReplicatedStorage.Shared.Features.Setting.Rules.SettingRules)
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
	describe("SettingServiceServer", function()
		local seeded = {}
		-- RequestHandler rate-limits per player; each test uses its own fake player id.
		local nextFakeId = 9100

		local function seed(userId)
			local profile = makeFakeProfile(makeProfileData())
			seeded[userId] = true
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile
		end

		local function fakePlayer()
			nextFakeId += 1
			seed(nextFakeId)
			return { UserId = nextFakeId, Name = `Spec{nextFakeId}` }
		end

		afterEach(function()
			for userId in seeded do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
			end
			seeded = {}
		end)

		it("reads defaults until a setting is changed, and nil for an unloaded profile", function()
			seed(1)
			expect(SettingService:get(1, "musicVolume")).to.equal(1)
			expect(SettingService:get(1, "no-such-setting")).to.equal(nil)
			expect(SettingService:get(999, "musicVolume")).to.equal(nil)
		end)

		it("sets a value, snapped to its step", function()
			local profile = seed(1)
			expect(SettingService:set(1, "musicVolume", 0.52)).to.equal(true)
			expect(SettingService:get(1, "musicVolume")).to.equal(0.5)
			expect(profile.Data.account.settings.values.musicVolume).to.equal(0.5)
		end)

		it("stores the default as absence", function()
			local profile = seed(1)
			SettingService:set(1, "musicVolume", 0.5)
			SettingService:set(1, "musicVolume", 1)
			expect(profile.Data.account.settings.values.musicVolume).to.equal(nil)
		end)

		it("refuses unknown ids, wrong types and out-of-range values", function()
			seed(1)
			expect((SettingService:set(1, "no-such-setting", 1))).to.equal(false)
			expect((SettingService:set(1, "musicVolume", "loud"))).to.equal(false)
			expect((SettingService:set(1, "musicVolume", 5))).to.equal(false)
			expect((SettingService:set(1, "keybinds", "interact=kb:Nope"))).to.equal(false)
			expect(SettingService:get(1, "musicVolume")).to.equal(1)
		end)

		it("resets one setting or all of them", function()
			seed(1)
			SettingService:set(1, "musicVolume", 0.2)
			SettingService:set(1, "sfxVolume", 0.3)
			expect(SettingService:reset(1, "musicVolume")).to.equal(true)
			expect(SettingService:get(1, "musicVolume")).to.equal(1)
			expect(SettingService:get(1, "sfxVolume")).to.equal(0.3)
			expect(SettingService:reset(1)).to.equal(true)
			expect(SettingService:get(1, "sfxVolume")).to.equal(1)
		end)

		it("applies a client's set, reset and resetAll requests", function()
			local player = fakePlayer()
			SettingService._onRequest(SettingRules.buildSet("cameraShake", 0.25), player)
			expect(SettingService:get(player.UserId, "cameraShake")).to.equal(0.25)
			SettingService._onRequest(SettingRules.buildReset("cameraShake"), player)
			expect(SettingService:get(player.UserId, "cameraShake")).to.equal(1)
			SettingService._onRequest(SettingRules.buildSet("keybinds", "interact=kb:F"), player)
			expect(SettingService:get(player.UserId, "keybinds")).to.equal("interact=kb:F")
			SettingService._onRequest(SettingRules.buildResetAll(), player)
			expect(SettingService:get(player.UserId, "keybinds")).to.equal("")
		end)

		it("ignores malformed and refused requests", function()
			local player = fakePlayer()
			SettingService._onRequest({ kind = "set", id = "musicVolume", value = {} }, player)
			SettingService._onRequest("garbage", player)
			SettingService._onRequest(SettingRules.buildSet("musicVolume", 7), player)
			expect(SettingService:get(player.UserId, "musicVolume")).to.equal(1)
		end)
	end)
end
