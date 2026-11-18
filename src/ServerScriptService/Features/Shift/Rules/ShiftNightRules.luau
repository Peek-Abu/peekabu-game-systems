--!strict
--[=[
	ShiftNightRules: the Night Shift run's decisions (ShiftNightConstants, ShiftNightFormulas). It reads the run mode
	off the untrusted depart payload (`parseMode`), keeps the weekly quota the sum of its nights' goals (`weekQuota`),
	settles a night at its results (`settle`: the week's clearance, the week bonus, fired or wiped) and stamps the run's
	fields onto the shift's state, raising a running night's tier to its start tier (`stamp`, `minTier`). Pure.

	@class ShiftNightRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftNightConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftNightConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftNightFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftNightFormulas)

type RunMode = ShiftTypes.RunMode
type RunOver = ShiftTypes.RunOver

-- The run's fields as the shift's state carries them (ShiftNightTracker.view). A quick shift has only `runMode`.
export type NightView = {
	runMode: RunMode,
	night: number?,
	week: number?,
	weekQuota: number?,
	weekCleared: number?,
	runOver: RunOver?,
	nightReached: number?,
}

-- One night's end, as `settle` reads it.
export type NightEnd = {
	night: number,
	-- The week's clearance before this night, and its quota.
	weekCleared: number,
	weekQuota: number,
	-- The Gloom this night cleared.
	cleared: number,
	-- Everyone ran out of coats (Round's "wiped").
	wiped: boolean?,
}

export type Settlement = {
	-- The week's clearance with this night's added.
	weekCleared: number,
	-- Credits each present crew member gets for meeting the weekly quota (0: none).
	bonus: number,
	-- The weekly quota was met: the next night starts a new week.
	newWeek: boolean,
	-- The run is over (nil: it goes on).
	runOver: RunOver?,
}

local function modeOf(value: unknown): RunMode?
	if value == ShiftNightConstants.MODE_NIGHT then
		return "night"
	elseif value == ShiftNightConstants.MODE_QUICK then
		return "quick"
	end
	return nil
end

local ShiftNightRules = {}

--[=[
	The run mode from the depart payload's MODE_KEY value (untrusted: it rode the teleport). Missing or unknown is
	DEFAULT_MODE.
]=]
function ShiftNightRules.parseMode(value: unknown): RunMode
	return modeOf(value) or modeOf(ShiftNightConstants.DEFAULT_MODE) or "night"
end

--[=[
	The weekly quota as of `night`: the goals of the week's nights already played (`goalsBefore`) plus this night's
	`goal` for this night and each one left in the week. On the week's last night it is exactly its nights' goals.
]=]
function ShiftNightRules.weekQuota(goalsBefore: number, goal: number, night: number): number
	local left = ShiftNightConstants.WEEK_NIGHTS - ShiftNightFormulas.nightOfWeek(night) + 1
	return goalsBefore + goal * left
end

--[=[
	A night's end: its clearance joins the week's. On the week's last night a met weekly quota pays the week bonus and
	starts a new week, a missed one fires the crew. A wipe ends the run too (a missed week still reads "fired").
]=]
function ShiftNightRules.settle(input: NightEnd): Settlement
	local weekCleared = input.weekCleared + math.max(0, input.cleared)
	local bonus = 0
	local newWeek = false
	local runOver: RunOver? = nil
	if ShiftNightFormulas.endsWeek(input.night) then
		if weekCleared >= input.weekQuota then
			bonus = ShiftNightFormulas.weekBonus(ShiftNightFormulas.week(input.night))
			newWeek = true
		else
			runOver = "fired"
		end
	end
	if input.wiped == true and runOver == nil then
		runOver = "wiped"
	end
	return { weekCleared = weekCleared, bonus = bonus, newWeek = newWeek, runOver = runOver }
end

--[=[
	The lowest tier the Manager may have this night: the night's start tier in Night Shift (ShiftNightFormulas.startTier),
	0 in a quick shift, in training or with no night.
]=]
function ShiftNightRules.minTier(mode: RunMode, night: number?, training: boolean): number
	if mode ~= "night" or night == nil or training then
		return 0
	end
	return ShiftNightFormulas.startTier(night, ShiftConstants.TOP_TIER)
end

--[=[
	A copy of `state` with the run's fields from `view` (a quick shift clears the night fields), and a running night's
	tier raised to `minTier`.
]=]
function ShiftNightRules.stamp(state: ShiftTypes.ShiftState, view: NightView, training: boolean): ShiftTypes.ShiftState
	local nextState = table.clone(state)
	nextState.runMode = view.runMode
	nextState.night = view.night
	nextState.week = view.week
	nextState.weekQuota = view.weekQuota
	nextState.weekCleared = view.weekCleared
	nextState.runOver = view.runOver
	nextState.nightReached = view.nightReached
	if nextState.phase == "running" then
		nextState.tier = math.max(nextState.tier, ShiftNightRules.minTier(view.runMode, view.night, training))
	end
	return nextState
end

return ShiftNightRules
