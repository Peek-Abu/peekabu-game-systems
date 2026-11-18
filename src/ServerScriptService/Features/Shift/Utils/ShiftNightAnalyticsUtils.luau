--!strict
--[=[
	ShiftNightAnalyticsUtils: the Night Shift's analytics records (owner 11-18: "Yes, add it"), one per happening, never
	per tick: the mode a crew departed with (`mode`), each night reached (`night`), how a run ended and on which night
	(`runEnd`), each week completed (`weekDone`, the week report) and the Next night / Clock out vote's result (`vote`).
	Each is a Creator Hub custom event: a fixed name, a number value and up to three short fields from a closed list
	(night and week numbers are capped, so a field never grows a long tail). ShiftNightSystem sends them through
	AnalyticsServiceServer:nightShift, behind the `nightShift` switch. Pure.

	@class ShiftNightAnalyticsUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftNightFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftNightFormulas)

export type Record = {
	event: string,
	value: number?,
	fields: { string },
}

local ShiftNightAnalyticsUtils = {}

-- Nights and weeks past these read "night_30_plus" / "week_10_plus" in the fields (the value keeps the real number).
ShiftNightAnalyticsUtils.NIGHT_CAP = 30
ShiftNightAnalyticsUtils.WEEK_CAP = 10

local function whole(value: number): number
	return math.max(1, math.floor(value))
end

local function capped(word: string, value: number, cap: number): string
	if value > cap then
		return `{word}_{cap}_plus`
	end
	return `{word}_{value}`
end

local function nightField(night: number): string
	return capped("night", whole(night), ShiftNightAnalyticsUtils.NIGHT_CAP)
end

-- The mode the crew departed with ("night" or "quick").
function ShiftNightAnalyticsUtils.mode(mode: ShiftTypes.RunMode): Record
	return { event = "night_shift_mode", value = nil, fields = { mode } }
end

-- A night reached: the value is the night, the fields its number and its week.
function ShiftNightAnalyticsUtils.night(night: number): Record
	local n = whole(night)
	local week = ShiftNightFormulas.week(n)
	return {
		event = "night_shift_night",
		value = n,
		fields = { nightField(n), capped("week", week, ShiftNightAnalyticsUtils.WEEK_CAP) },
	}
end

-- How a run ended (fired, wiped or clockout) and the night it ended on.
function ShiftNightAnalyticsUtils.runEnd(reason: ShiftTypes.RunOver, night: number): Record
	return { event = "night_shift_run_end", value = whole(night), fields = { reason, nightField(night) } }
end

-- A week completed (the week report): the value is the week, the fields the week and the bonus paid.
function ShiftNightAnalyticsUtils.weekDone(week: number, bonus: number): Record
	local w = whole(week)
	return {
		event = "night_shift_week_done",
		value = w,
		fields = { capped("week", w, ShiftNightAnalyticsUtils.WEEK_CAP), `bonus_{math.max(0, math.floor(bonus))}` },
	}
end

-- The vote's result on `night`: Clock out (`depot`) or Next night.
function ShiftNightAnalyticsUtils.vote(depot: boolean, night: number): Record
	return {
		event = "night_shift_vote",
		value = whole(night),
		fields = { if depot then "clock_out" else "next_night", nightField(night) },
	}
end

return ShiftNightAnalyticsUtils
