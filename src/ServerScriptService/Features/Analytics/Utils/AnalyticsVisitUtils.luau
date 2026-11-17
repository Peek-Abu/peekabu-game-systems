--!strict
--[=[
	AnalyticsVisitUtils: the pure decisions behind the visit events (quits, hub time, shifts per visit): whether a
	loading save continues the visit a truck ride stamped, what a quit came right after, the lifetime shift total's
	bucket and a stay's whole seconds.

	@class AnalyticsVisitUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsConstants = require(ServerScriptService.Features.Analytics.Data.AnalyticsConstants)
local AnalyticsTypes = require(ServerScriptService.Features.Analytics.Data.AnalyticsTypes)

-- Strongest first: a knock-out beats a catch, a catch beats a chase.
local PRIORITY: { AnalyticsTypes.Moment } = { "knocked_out", "caught", "chased" }

-- The lifetime buckets' lower bounds and names, highest first.
local BUCKETS: { { from: number, name: string } } = {
	{ from = 50, name = "50+" },
	{ from = 25, name = "25-49" },
	{ from = 10, name = "10-24" },
	{ from = 5, name = "5-9" },
	{ from = 3, name = "3-4" },
	{ from = 2, name = "2" },
	{ from = 1, name = "1" },
}

local AnalyticsVisitUtils = {}

--[=[
	Whether a save loading at `now` continues the visit whose truck ride stamped `handoffAt` (0: no stamp): within
	HANDOFF_WINDOW seconds after it.
]=]
function AnalyticsVisitUtils.continues(handoffAt: number, now: number): boolean
	return handoffAt > 0 and now >= handoffAt and now - handoffAt <= AnalyticsConstants.HANDOFF_WINDOW
end

--[=[
	What a quit at `now` came right after: the strongest moment within AFTER_WINDOW seconds, else "nothing".
]=]
function AnalyticsVisitUtils.after(moments: { [AnalyticsTypes.Moment]: number }, now: number): AnalyticsTypes.After
	for _, moment: AnalyticsTypes.Moment in PRIORITY do
		local at = moments[moment]
		if at ~= nil and now - at <= AnalyticsConstants.AFTER_WINDOW then
			return moment
		end
	end
	return "nothing"
end

--[=[
	The bucket a lifetime shift total falls in ("0", "1", "2", "3-4", "5-9", "10-24", "25-49", "50+").
]=]
function AnalyticsVisitUtils.bucket(shifts: number): string
	for _, bucket in BUCKETS do
		if shifts >= bucket.from then
			return bucket.name
		end
	end
	return "0"
end

--[=[
	The whole seconds from `since` to `now`, at least 0 and at most MAX_SECONDS.
]=]
function AnalyticsVisitUtils.seconds(since: number, now: number): number
	return math.clamp(math.floor(now - since), 0, AnalyticsConstants.MAX_SECONDS)
end

return table.freeze(AnalyticsVisitUtils)
