--!strict
--[=[
	AnalyticsSwitchUtils: the pure rule behind a tracking switch. A config value that is a boolean wins; anything else
	(missing, a string, a number, JSON) falls back to the code's constant (AnalyticsSwitchConstants).

	@class AnalyticsSwitchUtils
]=]

local AnalyticsSwitchUtils = {}

--[=[
	The switch's state: `value` when it is a boolean, else `fallback`.
]=]
function AnalyticsSwitchUtils.resolve(value: unknown, fallback: boolean): boolean
	if type(value) == "boolean" then
		return value
	end
	return fallback
end

return table.freeze(AnalyticsSwitchUtils)
