--!strict
--[=[
	AnalyticsContextUtils: builds the one context field every week-1 analytics event carries:
	`tags|platform|party|cohort|build`. Pure.

	@class AnalyticsContextUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsConstants = require(ServerScriptService.Features.Analytics.Data.AnalyticsConstants)
local AnalyticsTypes = require(ServerScriptService.Features.Analytics.Data.AnalyticsTypes)

type Cohort = AnalyticsTypes.Cohort
type Context = AnalyticsTypes.Context

local MAX_PARTY = 99

local AnalyticsContextUtils = {}

--[=[
	"unk" without a first-seen time, "new" inside the first day, otherwise "ret".
]=]
function AnalyticsContextUtils.cohort(firstSeen: number?, now: number): Cohort
	if firstSeen == nil then
		return "unk"
	end
	if now - firstSeen < AnalyticsConstants.NEW_WINDOW then
		return "new"
	end
	return "ret"
end

--[=[
	Variants joined with "+", or "-" when there are none.
]=]
function AnalyticsContextUtils.tags(variants: { string }): string
	if #variants == 0 then
		return "-"
	end
	return table.concat(variants, "+")
end

--[=[
	"w1-v42", or "w1-dev" when the place has no version (0, as in Studio).
]=]
function AnalyticsContextUtils.build(label: string, placeVersion: number): string
	if placeVersion == 0 then
		return `{label}-dev`
	end
	return `{label}-v{placeVersion}`
end

--[=[
	The packed field; the party is floored and clamped to 0..99.
]=]
function AnalyticsContextUtils.field(context: Context): string
	local party = math.clamp(math.floor(context.party), 0, MAX_PARTY)
	return `{context.tags}|{context.platform}|{party}|{context.cohort}|{context.build}`
end

return AnalyticsContextUtils
