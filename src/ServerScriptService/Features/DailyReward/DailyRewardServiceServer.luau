--!strict
--[=[
	DailyRewardServiceServer: the account-wide daily streak and its claims (design:
	docs/superpowers/specs/2026-10-09-small-services-design.md).

	A claim commits the streak update and the game's reward ops (from `setRewards`) in ONE transaction, so
	a reward is never granted without the claim being recorded, or the reverse. Days are cut on the
	server's clock (UTC + DAY_OFFSET_HOURS). Clients claim through DailyRewardEvents.Claim (rate limited)
	and read the replicated `dailyReward` slice.

	@class DailyRewardServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DailyRewardShared = ReplicatedStorage.Shared.Features.DailyReward
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local DailyRewardConstants = require(DailyRewardShared.Data.DailyRewardConstants)
local DailyRewardEvents = require(DailyRewardShared.Net.DailyRewardEvents)
local DailyRewardRules = require(DailyRewardShared.Rules.DailyRewardRules)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)

type TransactionOperation = PlayerDataService.TransactionOperation
export type RewardFor = (player: Player, cycleDay: number, streak: number) -> { TransactionOperation }

local dailySlice = PlayerDataSliceSystem.registerAccount("dailyReward", {
	lastDay = 0,
	streak = 0,
}, function(account)
	return account.dailyReward
end, DailyRewardRules.validate)

local log = Logger.new("DailyRewardServiceServer")
local claimed: SignalTyped.Signal<Player, number, number> = SignalTyped.new()
local rewardFor: RewardFor? = nil
local clock: () -> number = os.time
local stoppers: { () -> () } = {}

local function today(): number
	return DailyRewardRules.dayOf(clock(), DailyRewardConstants.DAY_OFFSET_HOURS)
end

export type DailyRewardServiceServer = {
	dependencies: { string },
	claimed: SignalTyped.Signal<Player, number, number>,
	init: (self: DailyRewardServiceServer) -> (),
	stop: (self: DailyRewardServiceServer) -> (),
	setRewards: (self: DailyRewardServiceServer, rewards: RewardFor?) -> (),
	status: (self: DailyRewardServiceServer, player: Player) -> DailyRewardRules.Status?,
	claim: (self: DailyRewardServiceServer, player: Player) -> (boolean, string?),
	reset: (self: DailyRewardServiceServer, userId: number) -> boolean,
	-- Test seam: replace the clock (seconds since the epoch); nil restores os.time.
	_setClock: (self: DailyRewardServiceServer, nextClock: (() -> number)?) -> (),
	getState: (self: DailyRewardServiceServer) -> { [string]: any },
}

local DailyRewardServiceServer: DailyRewardServiceServer

local onClaim = RequestHandler.wrap({
	name = "DailyRewardClaim",
	rateLimit = DailyRewardConstants.CLAIM_RATE,
	handler = function(_data: unknown, player: Player)
		local ok, reason = DailyRewardServiceServer:claim(player)
		if not ok then
			log:debug(`daily claim refused for {player.Name}: {reason or "?"}`)
		end
	end,
})

DailyRewardServiceServer = {
	dependencies = { "PlayerDataServiceServer" },
	claimed = claimed,

	init = function(_self)
		table.insert(
			stoppers,
			DailyRewardEvents.packets.Claim.listen(function(data: boolean, player: Player?)
				if player then
					onClaim(data, player)
				end
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		What each reward day gives, as transaction ops (`cycleDay` 1..CYCLE_LENGTH, `streak` the full
		streak). Nil means a claim only advances the streak.
	]=]
	setRewards = function(_self, rewards)
		rewardFor = rewards
	end,

	--[=[
		Today's status for the player, or nil when the profile is not loaded.
	]=]
	status = function(_self, player)
		local state = dailySlice.get(player.UserId)
		if state == nil then
			return nil
		end
		return DailyRewardRules.status(state, today(), DailyRewardConstants.CYCLE_LENGTH)
	end,

	--[=[
		Claims today's reward: the streak and the reward commit together. False with a reason when it is
		already claimed, the profile is not loaded, or the reward could not be granted.
	]=]
	claim = function(self, player)
		local status = self:status(player)
		if status == nil then
			return false, "profile not loaded"
		end
		if not status.claimable then
			return false, "already claimed today"
		end
		local day = today()
		local ops: { TransactionOperation } = {
			dailySlice.op(player.UserId, function(state)
				local ok = DailyRewardRules.claim(state, day, DailyRewardConstants.CYCLE_LENGTH)
				return ok
			end),
		}
		local rewards = rewardFor
		if rewards ~= nil then
			local ok, extra = pcall(rewards, player, status.cycleDay, status.nextStreak)
			if not ok then
				log:error(`daily reward handler errored: {extra}`)
				return false, "reward handler errored"
			end
			table.move(extra, 1, #extra, #ops + 1, ops)
		end
		local committed, result = PlayerDataService:transaction(ops)
		if not committed then
			return false, result.rejectionReason or "the claim was refused"
		end
		claimed:Fire(player, status.cycleDay, status.nextStreak)
		return true, nil
	end,

	--[=[
		Clears a player's streak (admin / testing).
	]=]
	reset = function(_self, userId)
		local changed = dailySlice.mutate(userId, function(state)
			if state.lastDay == 0 and state.streak == 0 then
				return false
			end
			state.lastDay = 0
			state.streak = 0
			return true
		end)
		return changed
	end,

	_setClock = function(_self, nextClock)
		clock = nextClock or os.time
	end,

	getState = function(_self)
		return { today = today(), cycleLength = DailyRewardConstants.CYCLE_LENGTH, hasRewards = rewardFor ~= nil }
	end,
}

return DailyRewardServiceServer
