--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConstants = require(ReplicatedStorage.Shared.Features.Event.Data.EventConstants)
local EventRegistry = require(ReplicatedStorage.Shared.Features.Event.Data.EventRegistry)

-- Sets the Workspace EventPreview attribute (EventConstants): the server and every client then treat that event as
-- live on this server whatever the date (EventUtils.live). "off" clears it. Acorns earned in a preview are real
-- balances on the profiles that earn them, so preview on test servers only.
return function(_context: unknown, eventId: string): string
	if eventId == "off" or eventId == "" then
		workspace:SetAttribute(EventConstants.PREVIEW_ATTRIBUTE, "")
		return "Event preview off: events follow their dates."
	end
	local event = EventRegistry.get(eventId)
	if event == nil then
		return `No event called "{eventId}".`
	end
	workspace:SetAttribute(EventConstants.PREVIEW_ATTRIBUTE, event.id)
	return `Previewing {event.name} ({event.id}) on this server.`
end
