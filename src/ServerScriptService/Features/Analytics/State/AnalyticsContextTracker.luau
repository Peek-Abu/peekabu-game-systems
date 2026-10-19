--!strict
--[=[
	AnalyticsContextTracker: what week-1 analytics remembers per player: the platform (first real report wins),
	the cohort, which funnel steps were already logged, and whether the experiment assignment was logged.
	Forgotten when the player leaves.

	@class AnalyticsContextTracker
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsTypes = require(ServerScriptService.Features.Analytics.Data.AnalyticsTypes)

type Cohort = AnalyticsTypes.Cohort

export type AnalyticsContextTracker = {
	setPlatform: (self: AnalyticsContextTracker, userId: number, platform: string) -> boolean,
	platformOf: (self: AnalyticsContextTracker, userId: number) -> string,
	setCohort: (self: AnalyticsContextTracker, userId: number, cohort: Cohort) -> (),
	cohortOf: (self: AnalyticsContextTracker, userId: number) -> Cohort,
	markStep: (self: AnalyticsContextTracker, userId: number, step: number) -> boolean,
	markAssigned: (self: AnalyticsContextTracker, userId: number) -> boolean,
	forget: (self: AnalyticsContextTracker, userId: number) -> (),
}

local AnalyticsContextTracker = {}

function AnalyticsContextTracker.new(): AnalyticsContextTracker
	local platforms: { [number]: string } = {}
	local cohorts: { [number]: Cohort } = {}
	local steps: { [number]: { [number]: boolean } } = {}
	local assigned: { [number]: boolean } = {}

	local tracker: AnalyticsContextTracker = {
		setPlatform = function(_self, userId, platform)
			if platform == "unknown" or platforms[userId] ~= nil then
				return false
			end
			platforms[userId] = platform
			return true
		end,

		platformOf = function(_self, userId)
			return platforms[userId] or "unknown"
		end,

		setCohort = function(_self, userId, cohort)
			cohorts[userId] = cohort
		end,

		cohortOf = function(_self, userId)
			return cohorts[userId] or "unk"
		end,

		markStep = function(_self, userId, step)
			local done = steps[userId]
			if done == nil then
				done = {}
				steps[userId] = done
			end
			if done[step] then
				return false
			end
			done[step] = true
			return true
		end,

		markAssigned = function(_self, userId)
			if assigned[userId] then
				return false
			end
			assigned[userId] = true
			return true
		end,

		forget = function(_self, userId)
			platforms[userId] = nil
			cohorts[userId] = nil
			steps[userId] = nil
			assigned[userId] = nil
		end,
	}
	return tracker
end

return AnalyticsContextTracker
