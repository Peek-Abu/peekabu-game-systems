--[[
	Unit tests for SocialServiceServer. Same strategy as the DailyReward spec: seed REAL fake profiles via
	`_setProfileForTesting` and drive the REAL transaction()/validator machinery; Roblox's group, join data and
	presence checks are hooks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataServer = ServerScriptService.Features.PlayerData
local PlayerDataMigrationSystem = require(PlayerDataServer.Systems.PlayerDataMigrationSystem)
local PlayerDataConstants = require(PlayerDataServer.Data.PlayerDataConstants)
local PlayerDataService = require(PlayerDataServer.PlayerDataServiceServer)
local SocialService = require(ServerScriptService.Features.Social.SocialServiceServer)
local StateSyncServerStore = require(ServerScriptService.Features.StateSync.State.StateSyncServerStore)
local SocialConstants = require(ReplicatedStorage.Shared.Features.Social.Data.SocialConstants)
local SocialRules = require(ReplicatedStorage.Shared.Features.Social.Rules.SocialRules)
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

local function makeProfileData(xp)
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
			coffee = { vouchers = 0 },
			premium = { balance = 0 },
			receipts = { ids = {} },
			firstSeen = { at = 0 },
			loadout = { current = "Pippa", picked = false, looks = {}, stickers = { "", "", "", "" }, seen = {} },
			entitlements = { owned = {} },
			settings = { values = {} },
			dailyReward = { lastDay = 0, streak = 0 },
			rank = { season = "mvp-1", xp = xp or 0, lastAwardedRunId = "" },
			social = SocialRules.fresh(),
		},
		slots = slots,
	}
end

return function()
	describe("SocialServiceServer", function()
		local seeded = {}
		local inGroup = {}
		local joinData = {}
		local present = {}
		local toasts = {}
		local now = 1000000

		local function seed(userId, xp)
			local profile = makeFakeProfile(makeProfileData(xp))
			seeded[userId] = true
			present[userId] = true
			PlayerDataService:_setProfileForTesting(userId, profile)
			return profile, { UserId = userId, Name = `Spec{userId}` }
		end

		beforeEach(function()
			inGroup, joinData, present, toasts = {}, {}, {}, {}
			now = 1000000
			SocialService:_setHooks({
				inGroup = function(player)
					return inGroup[player.UserId] == true
				end,
				joinData = function(player)
					return joinData[player.UserId] or {}
				end,
				present = function(userId)
					return present[userId] == true
				end,
				toast = function(userId, text)
					table.insert(toasts, { userId = userId, text = text })
				end,
				clock = function()
					return now
				end,
			})
		end)

		afterEach(function()
			SocialService:_setHooks(nil)
			for userId in seeded do
				PlayerDataService:_setProfileForTesting(userId, nil)
				StateSyncServerStore.remove(userId)
			end
			seeded = {}
		end)

		describe("checkGroup", function()
			it("pays a group member once, with a toast", function()
				local profile, player = seed(1)
				inGroup[1] = true
				expect(SocialService:checkGroup(player)).to.equal(true)
				expect(profile.Data.account.premium.balance).to.equal(SocialConstants.GROUP_GLEAM)
				expect(profile.Data.account.social.groupPaid).to.equal(true)
				expect(#toasts).to.equal(1)
				local ok, reason = SocialService:checkGroup(player)
				expect(ok).to.equal(false)
				expect(reason).to.equal("already paid")
				expect(profile.Data.account.premium.balance).to.equal(SocialConstants.GROUP_GLEAM)
			end)

			it("pays nothing to a non-member", function()
				local profile, player = seed(1)
				local ok, reason = SocialService:checkGroup(player)
				expect(ok).to.equal(false)
				expect(reason).to.equal("not in the group")
				expect(profile.Data.account.premium.balance).to.equal(0)
				expect(profile.Data.account.social.groupPaid).to.equal(false)
			end)
		end)

		describe("recordReferrer", function()
			it("records the inviter from the launch data for a new player", function()
				local profile, player = seed(2)
				joinData[2] = { LaunchData = SocialRules.launchData(1) }
				expect(SocialService:recordReferrer(player)).to.equal(true)
				expect(profile.Data.account.social.referredBy).to.equal(1)
			end)

			it("ignores a player who already finished a shift", function()
				local profile, player = seed(2, 40)
				joinData[2] = { LaunchData = SocialRules.launchData(1) }
				expect(SocialService:recordReferrer(player)).to.equal(false)
				expect(profile.Data.account.social.referredBy).to.equal(0)
			end)

			it("never records the player as their own inviter", function()
				local profile, player = seed(2)
				joinData[2] = { LaunchData = SocialRules.launchData(2) }
				expect(SocialService:recordReferrer(player)).to.equal(false)
				expect(profile.Data.account.social.referredBy).to.equal(0)
			end)
		end)

		describe("payReferrals", function()
			it("pays the friend and the inviter together, once", function()
				local inviter = seed(1, 100)
				local friend, friendPlayer = seed(2)
				joinData[2] = { LaunchData = SocialRules.launchData(1) }
				SocialService:recordReferrer(friendPlayer)
				expect(SocialService:payReferrals({ 1, 2 })).to.equal(1)
				expect(friend.Data.account.premium.balance).to.equal(SocialConstants.REFERRAL_GLEAM)
				expect(friend.Data.account.social.referralPaid).to.equal(true)
				expect(inviter.Data.account.premium.balance).to.equal(SocialConstants.REFERRAL_GLEAM)
				expect(inviter.Data.account.social.referrals).to.equal(1)
				expect(#toasts).to.equal(2)
				expect(SocialService:payReferrals({ 1, 2 })).to.equal(0)
				expect(inviter.Data.account.premium.balance).to.equal(SocialConstants.REFERRAL_GLEAM)
			end)

			it("still pays the friend when the inviter is gone", function()
				local friend, friendPlayer = seed(2)
				joinData[2] = { LaunchData = SocialRules.launchData(1) }
				SocialService:recordReferrer(friendPlayer)
				expect(SocialService:payReferrals({ 2 })).to.equal(1)
				expect(friend.Data.account.premium.balance).to.equal(SocialConstants.REFERRAL_GLEAM)
			end)

			it("stops paying the inviter at the cap", function()
				local inviter = seed(1, 100)
				inviter.Data.account.social.referrals = SocialConstants.REFERRAL_CAP
				local friend, friendPlayer = seed(2)
				joinData[2] = { LaunchData = SocialRules.launchData(1) }
				SocialService:recordReferrer(friendPlayer)
				expect(SocialService:payReferrals({ 1, 2 })).to.equal(1)
				expect(friend.Data.account.premium.balance).to.equal(SocialConstants.REFERRAL_GLEAM)
				expect(inviter.Data.account.premium.balance).to.equal(0)
				expect(inviter.Data.account.social.referrals).to.equal(SocialConstants.REFERRAL_CAP)
			end)
		end)

		describe("markAsked", function()
			it("stores when the ask was shown", function()
				local profile, player = seed(1)
				expect(SocialService:markAsked(player)).to.equal(true)
				expect(profile.Data.account.social.askedAt).to.equal(now)
			end)
		end)
	end)
end
