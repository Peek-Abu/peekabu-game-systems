--!strict
--[=[
	ShiftNightFormulas: the Night Shift mode's maths (ShiftNightConstants). Nights count from 1; every WEEK_NIGHTS nights
	is a week. Shared: the server sets each night's goal, length, pay and the manager's start from it, and the client's
	readout and screens show the night, the week and the anomaly level. Pure.

	@class ShiftNightFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftNightConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftNightConstants)

local ShiftNightFormulas = {}

local function safe(night: number): number
	return math.max(1, math.floor(night))
end

--[=[
	The week `night` falls in (1 for nights 1..WEEK_NIGHTS).
]=]
function ShiftNightFormulas.week(night: number): number
	return (safe(night) - 1) // ShiftNightConstants.WEEK_NIGHTS + 1
end

--[=[
	Which night of its week `night` is (1..WEEK_NIGHTS).
]=]
function ShiftNightFormulas.nightOfWeek(night: number): number
	return (safe(night) - 1) % ShiftNightConstants.WEEK_NIGHTS + 1
end

--[=[
	Whether `night` is its week's last (the weekly quota is checked after it).
]=]
function ShiftNightFormulas.endsWeek(night: number): boolean
	return ShiftNightFormulas.nightOfWeek(night) == ShiftNightConstants.WEEK_NIGHTS
end

--[=[
	The night's length in seconds: NIGHT_SECONDS by week, the last entry for every later week.
]=]
function ShiftNightFormulas.seconds(night: number): number
	local lengths = ShiftNightConstants.NIGHT_SECONDS
	return lengths[math.min(ShiftNightFormulas.week(night), #lengths)]
end

-- Week `week`'s starting share: QUOTA_SCALE by week, then +QUOTA_GROWTH a week.
local function weekScale(week: number): number
	local scales = ShiftNightConstants.QUOTA_SCALE
	if week <= #scales then
		return scales[week]
	end
	return scales[#scales] + (week - #scales) * ShiftNightConstants.QUOTA_GROWTH
end

--[=[
	The night's goal as a share of the shift contract: its week's share on the week's first night, climbing evenly toward
	the next week's over the week's nights (so it rises a little every night), at most QUOTA_SCALE_CAP.
]=]
function ShiftNightFormulas.quotaScale(night: number): number
	local week = ShiftNightFormulas.week(night)
	local from = weekScale(week)
	local step = (weekScale(week + 1) - from) / ShiftNightConstants.WEEK_NIGHTS
	local scale = from + step * (ShiftNightFormulas.nightOfWeek(night) - 1)
	return math.min(scale, ShiftNightConstants.QUOTA_SCALE_CAP)
end

--[=[
	The night's goal (Gloom) from the shift contract `contract` (ShiftQuotaFormulas.quota for the crew and map),
	rounded to QUOTA_STEP, at least one step.
]=]
function ShiftNightFormulas.nightQuota(contract: number, night: number): number
	local step = ShiftNightConstants.QUOTA_STEP
	local goal = math.floor(contract * ShiftNightFormulas.quotaScale(night) / step + 0.5) * step
	return math.max(step, goal)
end

--[=[
	The night's pay multiplier: 1 on night 1, +PAY_STEP each night after.
]=]
function ShiftNightFormulas.payScale(night: number): number
	return 1 + (safe(night) - 1) * ShiftNightConstants.PAY_STEP
end

--[=[
	The Credits each crew member gets for surviving week `week`.
]=]
function ShiftNightFormulas.weekBonus(week: number): number
	return math.max(1, math.floor(week)) * ShiftNightConstants.WEEK_BONUS
end

--[=[
	The manager's tier at the start of `night`: 0 in week 1, +TIER_PER_WEEK a week, at most `topTier`.
]=]
function ShiftNightFormulas.startTier(night: number, topTier: number): number
	return math.min((ShiftNightFormulas.week(night) - 1) * ShiftNightConstants.TIER_PER_WEEK, topTier)
end

--[=[
	The ANOMALY LEVEL (Gloom drops) the readout shows: the map's `danger` + one a week after the first, at most
	ANOMALY_MAX.
]=]
function ShiftNightFormulas.anomaly(night: number, danger: number): number
	return math.min(danger + ShiftNightFormulas.week(night) - 1, ShiftNightConstants.ANOMALY_MAX)
end

return ShiftNightFormulas
