--!strict
--[=[
	SocialServiceServer: the Odd Hours social perks (plan docs/superpowers/plans/2026-10-28-social-perks.md). It owns
	the `social` account slice (SocialRules).

	- **Group perk.** `checkGroup` pays GROUP_GLEAM once to a member of the Icey Labs group (Player:IsInGroupAsync),
	  the flag and the Gleam in one transaction. Checked when a profile loads and when the client says the join
	  prompt closed (SocialEvents.CheckGroup).
	- **Referral.** `recordReferrer` reads the inviter from the join's LaunchData (SocialServiceClient's invite), for a
	  player who has never finished a shift. When a shift's review lands,
	  `payReferrals` pays each referred crew member once, and their inviter in the same transaction while the inviter
	  is in this server and under REFERRAL_CAP.
	- **Friends.** As players join, every pair is checked once (Player:IsFriendsWithAsync) into
	  SocialFriendTracker.shared, which Shift's review reads for the "Friends x2" XP line.
	- **Ask.** `markAsked` stores when the client showed the favorite/like ask (SocialEvents.Asked). Nothing is paid
	  for a favorite or a like.

	Roblox calls, presence, toasts and the clock are hooks (`_setHooks`) so the spec drives the real data layer.

	@class SocialServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local SocialConstants = require(ReplicatedStorage.Shared.Features.Social.Data.SocialConstants)
local SocialEvents = require(ReplicatedStorage.Shared.Features.Social.Net.SocialEvents)
local SocialRules = require(ReplicatedStorage.Shared.Features.Social.Rules.SocialRules)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local ShiftReviewSystem = require(ServerScriptService.Features.Shift.Systems.ShiftReviewSystem)
local SocialFriendTracker = require(ServerScriptService.Features.Social.State.SocialFriendTracker)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

type TransactionOperation = PlayerDataService.TransactionOperation

-- What a join's GetJoinData holds that the referral reads.
export type JoinData = { LaunchData: string? }

export type Hooks = {
	inGroup: (player: Player) -> boolean,
	joinData: (player: Player) -> JoinData,
	present: (userId: number) -> boolean,
	toast: (userId: number, text: string) -> (),
	clock: () -> number,
}

local socialSlice = PlayerDataSliceSystem.registerAccount("social", SocialRules.fresh(), function(account)
	return account.social
end, SocialRules.validate)

local log = Logger.new("SocialServiceServer")

local function joinDataOf(player: Player): JoinData
	return { LaunchData = player:GetJoinData().LaunchData }
end

local defaults: Hooks = {
	inGroup = function(player)
		return player:IsInGroupAsync(SocialConstants.GROUP_ID)
	end,
	joinData = joinDataOf,
	present = function(userId)
		return Players:GetPlayerByUserId(userId) ~= nil
	end,
	toast = function(userId, text)
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			ToastServiceServer:send(player, { text = text, duration = 4 })
		end
	end,
	clock = os.time,
}

local hooks: Hooks = defaults
local stoppers: { () -> () } = {}
local paidRuns: { [number]: true } = {}

local function gleamOp(userId: number, amount: number): TransactionOperation
	return MarketplaceServiceServer:premiumOp(userId, function(premium: PlayerDataTypes.Premium)
		premium.balance += amount
		return true
	end)
end

local function gleamText(text: string, amount: number): string
	return `{text} +{amount} Gleam`
end

-- The XP a player has from finished shifts (0 when the profile is not loaded).
local function xpOf(userId: number): number
	local profile = PlayerDataService:getProfile(userId)
	return if profile ~= nil then profile.account.rank.xp else 0
end

-- Checks every pair of `player` and the others here once, into the shared friend tracker.
local function checkFriends(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local ok, friends = pcall(function()
					return player:IsFriendsWithAsync(other.UserId)
				end)
				if ok and player.Parent ~= nil and other.Parent ~= nil then
					SocialFriendTracker.shared:set(player.UserId, other.UserId, friends)
				end
			end)
		end
	end
end

export type SocialServiceServer = {
	dependencies: { string },
	init: (self: SocialServiceServer) -> (),
	start: (self: SocialServiceServer) -> (),
	stop: (self: SocialServiceServer) -> (),
	checkGroup: (self: SocialServiceServer, player: Player) -> (boolean, string?),
	recordReferrer: (self: SocialServiceServer, player: Player) -> boolean,
	payReferrals: (self: SocialServiceServer, userIds: { number }) -> number,
	markAsked: (self: SocialServiceServer, player: Player) -> boolean,
	-- Test seam: replace Roblox's calls, presence, toasts and the clock; nil restores the real ones.
	_setHooks: (self: SocialServiceServer, next: Hooks?) -> (),
	getState: (self: SocialServiceServer) -> { [string]: any },
}

local SocialServiceServer: SocialServiceServer

local onCheckGroup = RequestHandler.wrap({
	name = "SocialCheckGroup",
	rateLimit = SocialConstants.REQUEST_RATE,
	handler = function(_data: unknown, player: Player)
		local ok, reason = SocialServiceServer:checkGroup(player)
		if not ok then
			log:debug(`group perk refused for {player.Name}: {reason or "?"}`)
		end
	end,
})

local onAsked = RequestHandler.wrap({
	name = "SocialAsked",
	rateLimit = SocialConstants.REQUEST_RATE,
	handler = function(_data: unknown, player: Player)
		SocialServiceServer:markAsked(player)
	end,
})

SocialServiceServer = {
	dependencies = {
		"PlayerDataServiceServer",
		"MarketplaceServiceServer",
		"ShiftServiceServer",
		"ToastServiceServer",
	},

	init = function(_self)
		table.insert(
			stoppers,
			SocialEvents.packets.CheckGroup.listen(function(data: boolean, player: Player?)
				if player then
					onCheckGroup(data, player)
				end
			end)
		)
		table.insert(
			stoppers,
			SocialEvents.packets.Asked.listen(function(data: boolean, player: Player?)
				if player then
					onAsked(data, player)
				end
			end)
		)
	end,

	start = function(self)
		local loaded = PlayerDataService.profileLoaded:Connect(function(userId: number)
			local player = Players:GetPlayerByUserId(userId)
			if player == nil then
				return
			end
			self:recordReferrer(player)
			task.spawn(function()
				self:checkGroup(player)
			end)
		end)
		table.insert(stoppers, function()
			loaded:Disconnect()
		end)
		table.insert(
			stoppers,
			Observers.observePlayer(function(player: Player)
				checkFriends(player)
				return function()
					SocialFriendTracker.shared:forget(player.UserId)
				end
			end)
		)
		local reviewed = ShiftServiceServer.changed:Connect(function(state: ShiftTypes.ShiftState)
			if state.phase ~= "results" or paidRuns[state.shift] then
				return
			end
			paidRuns[state.shift] = true
			local ids: { number } = {}
			for _, member in ShiftReviewSystem.crew() do
				table.insert(ids, member.userId)
			end
			self:payReferrals(ids)
		end)
		table.insert(stoppers, function()
			reviewed:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		Pays the one-time group perk when the player is in the group. False with a reason when it was already paid,
		they are not a member (or the check failed), or the write was refused.
	]=]
	checkGroup = function(_self, player)
		local state = socialSlice.get(player.UserId)
		if state == nil then
			return false, "profile not loaded"
		end
		if state.groupPaid then
			return false, "already paid"
		end
		local ok, member = pcall(hooks.inGroup, player)
		if not ok then
			log:warn(`group check failed for {player.Name}: {member}`)
			return false, "group check failed"
		end
		if not member then
			return false, "not in the group"
		end
		local committed, result = PlayerDataService:transaction({
			socialSlice.op(player.UserId, function(social)
				if social.groupPaid then
					return false
				end
				social.groupPaid = true
				return true
			end),
			gleamOp(player.UserId, SocialConstants.GROUP_GLEAM),
		})
		if not committed then
			return false, result.rejectionReason or "the perk was refused"
		end
		hooks.toast(player.UserId, gleamText(SocialConstants.TEXT.groupPaid, SocialConstants.GROUP_GLEAM))
		return true, nil
	end,

	--[=[
		Records who invited a player who has never finished a shift. True when a referrer was recorded.
	]=]
	recordReferrer = function(_self, player)
		local state = socialSlice.get(player.UserId)
		if state == nil or not SocialRules.canRecordReferrer(state, xpOf(player.UserId)) then
			return false
		end
		local data = hooks.joinData(player)
		local inviter = SocialRules.referrerFrom(data.LaunchData, player.UserId)
		if inviter == nil then
			return false
		end
		local changed = socialSlice.mutate(player.UserId, function(social)
			if not SocialRules.canRecordReferrer(social, xpOf(player.UserId)) then
				return false
			end
			social.referredBy = inviter
			return true
		end)
		return changed
	end,

	--[=[
		Pays every referral owed among `userIds` (a finished shift's crew). Returns how many referred players were paid.
	]=]
	payReferrals = function(_self, userIds)
		local paid = 0
		for _, userId in userIds do
			local state = socialSlice.get(userId)
			if state ~= nil and SocialRules.referralOwed(state) then
				local inviter = state.referredBy
				local inviterState = if hooks.present(inviter) then socialSlice.get(inviter) else nil
				local payInviter = inviterState ~= nil and SocialRules.inviterPayable(inviterState)
				local ops: { TransactionOperation } = {
					socialSlice.op(userId, function(social)
						if not SocialRules.referralOwed(social) then
							return false
						end
						social.referralPaid = true
						return true
					end),
					gleamOp(userId, SocialConstants.REFERRAL_GLEAM),
				}
				if payInviter then
					table.insert(
						ops,
						socialSlice.op(inviter, function(social)
							if not SocialRules.inviterPayable(social) then
								return false
							end
							social.referrals += 1
							return true
						end)
					)
					table.insert(ops, gleamOp(inviter, SocialConstants.REFERRAL_GLEAM))
				end
				local committed, result = PlayerDataService:transaction(ops)
				if committed then
					paid += 1
					hooks.toast(userId, gleamText(SocialConstants.TEXT.referralInvitee, SocialConstants.REFERRAL_GLEAM))
					if payInviter then
						hooks.toast(
							inviter,
							gleamText(SocialConstants.TEXT.referralInviter, SocialConstants.REFERRAL_GLEAM)
						)
					end
				else
					log:warn(`referral pay-out for {userId} refused: {result.rejectionReason or "?"}`)
				end
			end
		end
		return paid
	end,

	--[=[
		Stores that the favorite/like ask was just shown. True when stored.
	]=]
	markAsked = function(_self, player)
		local now = hooks.clock()
		local changed = socialSlice.mutate(player.UserId, function(social)
			social.askedAt = now
			return true
		end)
		return changed
	end,

	_setHooks = function(_self, next)
		hooks = next or defaults
	end,

	getState = function(_self)
		local runs = 0
		for _ in paidRuns do
			runs += 1
		end
		return { groupId = SocialConstants.GROUP_ID, reviewedRuns = runs }
	end,
}

return SocialServiceServer
