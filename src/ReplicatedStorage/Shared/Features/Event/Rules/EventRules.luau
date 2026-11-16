--!strict
--[=[
	EventRules: the data-layer validator for the account-wide `events` slice (EventTypes.Events).

	@class EventRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventTypes = require(ReplicatedStorage.Shared.Features.Event.Data.EventTypes)

local EventRules = {}

-- Typed as the slice, checked as if it were anything (a save written by older code, or a bad op).
function EventRules.validate(state: EventTypes.Events): boolean
	local day: unknown = state.day
	return type(day) == "number" and day >= 0 and day == math.floor(day)
end

return EventRules
