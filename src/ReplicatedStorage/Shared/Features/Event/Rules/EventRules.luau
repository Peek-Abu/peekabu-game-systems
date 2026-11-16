--!strict
--[=[
	EventRules: the data-layer validator for the account-wide `events` slice (EventTypes.Events), and the shape check
	for the client's tab-shown request.

	@class EventRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventRegistry = require(ReplicatedStorage.Shared.Features.Event.Data.EventRegistry)
local EventTypes = require(ReplicatedStorage.Shared.Features.Event.Data.EventTypes)

local EventRules = {}

-- Typed as the slice, checked as if it were anything (a save written by older code, or a bad op).
function EventRules.validate(state: EventTypes.Events): boolean
	local day: unknown = state.day
	if type(day) ~= "number" or day < 0 or day ~= math.floor(day) then
		return false
	end
	local shown = state.shown
	if type(shown) ~= "table" then
		return false
	end
	for key: unknown, value: unknown in pairs(shown) do
		if type(key) ~= "string" or EventRegistry.get(key) == nil or value ~= true then
			return false
		end
	end
	return true
end

-- The client's tab-shown request (EventEvents.Shown): a registered event's id, else nil.
function EventRules.parseShown(payload: unknown): string?
	if type(payload) ~= "table" then
		return nil
	end
	local fields = payload :: { [string]: unknown } -- unknown -> indexable at the trust boundary; the field is shape-checked below
	local id = fields.event
	if type(id) ~= "string" or EventRegistry.get(id) == nil then
		return nil
	end
	return id
end

return EventRules
