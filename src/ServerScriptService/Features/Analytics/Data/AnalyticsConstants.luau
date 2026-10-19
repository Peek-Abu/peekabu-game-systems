--!strict
--[=[
	AnalyticsConstants: the week-1 analytics vocabulary: build label, the first-time funnel, the cohort window and
	which experiments tag which events. Frozen data.

	@class AnalyticsConstants
]=]

local FUNNEL_STEPS: { string } = table.freeze({
	"joined_hub",
	"boarded_truck",
	"shift_started",
	"first_cleanup",
	"first_pickup",
	"first_bank",
	"quota_met",
	"clocked_out",
	"results_viewed",
	"next_shift",
})

local FUNNEL_EXPERIMENTS: { string } = table.freeze({ "exp-tutorial", "exp-friendskip" })

-- Experiments that tag a currency's economy events (at most MAX_TAGS each).
local CURRENCY_EXPERIMENTS: { [string]: { string } } = table.freeze({
	gleam = table.freeze({ "exp-stars", "exp-starter" }),
	credits = table.freeze({ "exp-unlock", "exp-employee2" }),
	gloom = table.freeze({ "exp-timecard" }),
})

local AnalyticsConstants = {
	BUILD_LABEL = "w1",
	FUNNEL = "first_time",
	FUNNEL_STEPS = FUNNEL_STEPS,
	-- Seconds after first sight that an account still counts as "new".
	NEW_WINDOW = 86400,
	ASSIGNMENT_EVENT = "experiment_assigned",
	MAX_TAGS = 2,
	FUNNEL_EXPERIMENTS = FUNNEL_EXPERIMENTS,
	CURRENCY_EXPERIMENTS = CURRENCY_EXPERIMENTS,
}

--[=[
	The 1-based funnel step number for a step name; nil for an unknown name.
]=]
function AnalyticsConstants.stepNumber(name: string): number?
	return table.find(FUNNEL_STEPS, name)
end

return table.freeze(AnalyticsConstants)
