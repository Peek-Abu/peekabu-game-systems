--!strict
--[=[
	AnalyticsVisitRules: the "visit" account slice's rules (AnalyticsVisitSystem owns it): the data layer's validator,
	what a save loading does to it (`arrive`: the visit goes on after a truck ride, else a new one starts) and what a
	worked shift does (`worked`).

	@class AnalyticsVisitRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local AnalyticsVisitUtils = require(ServerScriptService.Features.Analytics.Utils.AnalyticsVisitUtils)

local function isCount(value: unknown): boolean
	return type(value) == "number" and value >= 0 and value == math.floor(value)
end

local AnalyticsVisitRules = {}

--[=[
	The data layer's validator: every field a whole number of 0 or more, and the visit's count never above the
	lifetime total.
]=]
function AnalyticsVisitRules.validate(value: PlayerDataTypes.Visit?): (boolean, string?)
	if value == nil then
		return false, "visit must be a table"
	end
	if not isCount(value.shifts) or not isCount(value.current) or not isCount(value.handoffAt) then
		return false, "visit fields must be whole numbers >= 0"
	end
	if value.current > value.shifts then
		return false, "visit.current must not exceed visit.shifts"
	end
	return true
end

--[=[
	A save loading at `now`: true (the visit goes on) when a truck ride stamped it within the handoff window, else
	the visit's count restarts at 0. The stamp is cleared either way.
]=]
function AnalyticsVisitRules.arrive(slice: PlayerDataTypes.Visit, now: number): boolean
	local continued = AnalyticsVisitUtils.continues(slice.handoffAt, now)
	if not continued then
		slice.current = 0
	end
	slice.handoffAt = 0
	return continued
end

--[=[
	One shift worked: into this visit's count and the lifetime total.
]=]
function AnalyticsVisitRules.worked(slice: PlayerDataTypes.Visit)
	slice.current += 1
	slice.shifts += 1
end

return table.freeze(AnalyticsVisitRules)
