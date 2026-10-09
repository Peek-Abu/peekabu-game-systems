--!strict
--[=[
	DailyRewardRules: day indices, whether a reward is claimable, the streak, and the slice validator.
	Pure; the clock is passed in.

	One claim per day. Claiming the day after the last claim continues the streak; any gap restarts it at
	1. The reward day cycles: with a 7-day cycle, streak 8 gives day 1's reward again.

	@class DailyRewardRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

type DailyReward = PlayerDataTypes.DailyReward

export type Status = {
	claimable: boolean,
	nextStreak: number,
	cycleDay: number,
}

local SECONDS_PER_DAY = 86400

local DailyRewardRules = {}

function DailyRewardRules.dayOf(timestamp: number, offsetHours: number): number
	return math.floor((timestamp + offsetHours * 3600) / SECONDS_PER_DAY)
end

function DailyRewardRules.status(state: DailyReward, today: number, cycleLength: number): Status
	local continues = state.lastDay == today - 1
	local nextStreak = if continues then state.streak + 1 else 1
	return {
		claimable = state.lastDay < today,
		nextStreak = nextStreak,
		cycleDay = ((nextStreak - 1) % cycleLength) + 1,
	}
end

--[=[
	Records today's claim (in place). Returns whether it was claimable and the reward day it gives.
]=]
function DailyRewardRules.claim(state: DailyReward, today: number, cycleLength: number): (boolean, number)
	local status = DailyRewardRules.status(state, today, cycleLength)
	if not status.claimable then
		return false, status.cycleDay
	end
	state.lastDay = today
	state.streak = status.nextStreak
	return true, status.cycleDay
end

local function isWhole(value: number): boolean
	return type(value) == "number" and value >= 0 and value == math.floor(value)
end

function DailyRewardRules.validate(state: DailyReward): (boolean, string?)
	if not isWhole(state.lastDay) or not isWhole(state.streak) then
		return false, "dailyReward.lastDay and streak must be whole numbers of at least 0"
	end
	return true, nil
end

return DailyRewardRules
