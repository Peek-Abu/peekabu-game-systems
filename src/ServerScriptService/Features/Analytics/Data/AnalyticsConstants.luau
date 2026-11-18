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

-- Field 1 of every funnel step carries only per-player experiments, so one player's funnel is never split between the
-- hub and the Shift place. A per-crew experiment (a hub is not a crew) rides in the step-varying third field.
local FUNNEL_EXPERIMENTS: { string } = table.freeze({ "exp-tutorial" })
local FUNNEL_CREW_EXPERIMENTS: { string } = table.freeze({ "exp-friendskip" })

-- Experiments that tag a currency's economy events (at most MAX_TAGS each).
local CURRENCY_EXPERIMENTS: { [string]: { string } } = table.freeze({
	gleam = table.freeze({ "exp-stars", "exp-starter" }),
	credits = table.freeze({ "exp-unlock", "exp-employee2" }),
	gloom = table.freeze({ "exp-timecard" }),
	acorns = table.freeze({}),
})

-- The name each economy currency is reported under.
local CURRENCY_NAMES: { [string]: string } = table.freeze({
	gloom = "Gloom",
	credits = "Credits",
	gleam = "Gleam",
	acorns = "Acorns",
})

-- Each loggable currency change reason -> an Enum.AnalyticsEconomyTransactionType name. A reason that is absent
-- ("admin", "other") is not logged.
local TRANSACTION_TYPES: { [string]: string } = table.freeze({
	shiftPay = "Gameplay",
})

-- The reasons that are deliberately not logged. Every CurrencyConstants ChangeReason is in exactly one of
-- TRANSACTION_TYPES or this list (spec-enforced).
local UNLOGGED_REASONS: { string } = table.freeze({ "admin", "other" })

-- The training funnel: the Training truck, the run starting, each of its stops (TrainingConstants.STOPS ids), done.
local TRAINING_STEPS: { string } = table.freeze({
	"truck",
	"started",
	"dust",
	"treasure",
	"quiet",
	"hide",
	"done",
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
	FUNNEL_CREW_EXPERIMENTS = FUNNEL_CREW_EXPERIMENTS,
	CURRENCY_EXPERIMENTS = CURRENCY_EXPERIMENTS,
	CURRENCY_NAMES = CURRENCY_NAMES,
	TRANSACTION_TYPES = TRANSACTION_TYPES,
	UNLOGGED_REASONS = UNLOGGED_REASONS,
	TRAINING_FUNNEL = "training",
	TRAINING_STEPS = TRAINING_STEPS,
	TRAINING_SKIPPED_EVENT = "training_skipped",
	-- A real quit (not a truck ride): where, and right after what.
	LEFT_EVENT = "left_game",
	-- A hub stay: its seconds, how it ended, first or again this visit.
	HUB_EVENT = "hub_visit",
	-- A visit's end (a real quit): the shifts this visit, the lifetime total's bucket.
	VISIT_EVENT = "visit_ended",
	-- A save that loads within this many seconds of a truck ride's stamp is the same visit.
	HANDOFF_WINDOW = 300,
	-- A catch, chase or knock-out this many seconds before a quit counts as what the quit came after.
	AFTER_WINDOW = 60,
	-- The longest hub stay reported, in seconds.
	MAX_SECONDS = 86400,
	-- The longest token a custom field carries.
	TOKEN_MAX = 50,
}

--[=[
	The 1-based funnel step number for a step name; nil for an unknown name.
]=]
function AnalyticsConstants.stepNumber(name: string): number?
	return table.find(FUNNEL_STEPS, name)
end

--[=[
	The 1-based training funnel step number for a step name; nil for an unknown name.
]=]
function AnalyticsConstants.trainingStepNumber(name: string): number?
	return table.find(TRAINING_STEPS, name)
end

return table.freeze(AnalyticsConstants)
