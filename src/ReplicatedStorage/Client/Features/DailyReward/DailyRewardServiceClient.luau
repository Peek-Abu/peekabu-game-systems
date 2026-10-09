--!strict
--[=[
	DailyRewardServiceClient: the local player's daily reward status and the claim request. Reads the
	replicated `dailyReward` slice (StateSyncClientStore.dailyReward) and the server clock; the server
	decides every claim.

	@class DailyRewardServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local DailyRewardConstants = require(ReplicatedStorage.Shared.Features.DailyReward.Data.DailyRewardConstants)
local DailyRewardEvents = require(ReplicatedStorage.Shared.Features.DailyReward.Net.DailyRewardEvents)
local DailyRewardRules = require(ReplicatedStorage.Shared.Features.DailyReward.Rules.DailyRewardRules)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

export type DailyRewardServiceClient = {
	dependencies: { string },
	dailyReward: () -> PlayerDataTypes.DailyReward,
	status: (self: DailyRewardServiceClient) -> DailyRewardRules.Status,
	secondsUntilNextDay: (self: DailyRewardServiceClient) -> number,
	claim: (self: DailyRewardServiceClient) -> (),
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local DailyRewardServiceClient: DailyRewardServiceClient = {
	dependencies = { "StateSyncServiceClient" },
	dailyReward = StateSyncClientStore.dailyReward,

	--[=[
		Today's status, on the server's clock.
	]=]
	status = function(_self)
		local today = DailyRewardRules.dayOf(now(), DailyRewardConstants.DAY_OFFSET_HOURS)
		return DailyRewardRules.status(StateSyncClientStore.dailyReward(), today, DailyRewardConstants.CYCLE_LENGTH)
	end,

	--[=[
		Seconds until the next day starts (for a "next reward in" timer).
	]=]
	secondsUntilNextDay = function(_self)
		local shifted = now() + DailyRewardConstants.DAY_OFFSET_HOURS * 3600
		return 86400 - (shifted % 86400)
	end,

	--[=[
		Asks the server to claim today's reward (the slice confirms it).
	]=]
	claim = function(self)
		if self:status().claimable then
			DailyRewardEvents.packets.Claim.send(true)
		end
	end,
}

return DailyRewardServiceClient
