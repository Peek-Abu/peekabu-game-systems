--!strict
--[=[
	ShiftNightRules: the Night Shift run's decisions (ShiftNightConstants, ShiftNightFormulas). It reads the run mode
	off the untrusted depart payload (`parseMode`), settles a night at its results (`settle`: tonight's goal is the only
	fail line, a wipe ends the run, a survived week pays its bonus), gives a nearly-made night its extra time
	(`extraTime`) and stamps the run's fields onto the shift's state,
	raising a running night's tier to its start tier (`stamp`, `minTier`). Pure.

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
	-- Set on the results of a survived week's last night (the week report): the bonus each crew member got.
	weekBonus: number?,
	runOver: RunOver?,
	nightReached: number?,
}

-- A night whose clock just ran out, as `extraTime` reads it. `night` is nil outside a Night Shift run; `used` is whether
-- this night already had its extra time.
export type ClockOut = {
	night: number?,
	training: boolean,
	used: boolean,
	quota: number,
	cleared: number,
	quotaMet: boolean,
}

-- One night's end, as `settle` reads it.
export type NightEnd = {
	night: number,
	-- Tonight's goal was met (the review's GOAL DONE!, ShiftResults.quotaMet).
	met: boolean,
	-- Everyone ran out of coats (Round's "wiped").
	wiped: boolean?,
}

export type Settlement = {
	-- Credits each present crew member gets for surviving the week (0: none).
	bonus: number,
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
	A night's end (owner 11-18: each night's goal is the only fail line, no weekly quota). A wipe ends the run
	("wiped"); otherwise a missed goal fires the crew ("fired"); a met goal on the week's last night pays the week
	bonus (a reward, never a goal).
]=]
function ShiftNightRules.settle(input: NightEnd): Settlement
	if input.wiped == true then
		return { bonus = 0, runOver = "wiped" }
	end
	if not input.met then
		return { bonus = 0, runOver = "fired" }
	end
	local bonus = if ShiftNightFormulas.endsWeek(input.night)
		then ShiftNightFormulas.weekBonus(ShiftNightFormulas.week(input.night))
		else 0
	return { bonus = bonus, runOver = nil }
end

--[=[
	The extra time (seconds) a night gets when its clock runs out (owner pick T3): EXTRA_TIME_SECONDS once a night when
	the crew has EXTRA_TIME_SHARE of tonight's goal or more but has not met it; 0 in a quick shift, in training, with
	no goal or once used.
]=]
function ShiftNightRules.extraTime(input: ClockOut): number
	if input.night == nil or input.training or input.used or input.quotaMet or input.quota <= 0 then
		return 0
	end
	if input.cleared < input.quota * ShiftNightConstants.EXTRA_TIME_SHARE then
		return 0
	end
	return ShiftNightConstants.EXTRA_TIME_SECONDS
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
	nextState.weekBonus = view.weekBonus
	nextState.runOver = view.runOver
	nextState.nightReached = view.nightReached
	if nextState.phase == "running" then
		nextState.tier = math.max(nextState.tier, ShiftNightRules.minTier(view.runMode, view.night, training))
	end
	return nextState
end

return ShiftNightRules
