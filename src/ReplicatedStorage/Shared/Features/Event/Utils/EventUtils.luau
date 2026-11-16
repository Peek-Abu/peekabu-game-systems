--!strict
--[=[
	EventUtils: which event is live at a UTC time, how many days it has left, and the day number the first-shift bonus
	counts by. Pure. `preview` is the admin preview (the EventPreview command): a registered event id shows that event
	at any time, "" or nil uses the dates.

	@class EventUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventTypes = require(ReplicatedStorage.Shared.Features.Event.Data.EventTypes)

type Event = EventTypes.Event

local DAY = 86400

local EventUtils = {}

function EventUtils.live(events: { Event }, now: number, preview: string?): Event?
	if preview ~= nil and preview ~= "" then
		for _, event in events do
			if event.id == preview then
				return event
			end
		end
	end
	for _, event in events do
		if now >= event.starts and now < event.ends then
			return event
		end
	end
	return nil
end

-- Whole days left (a started day counts); a previewed event outside its dates shows 1.
function EventUtils.daysLeft(event: Event, now: number, previewed: boolean?): number
	local days = math.max(0, math.ceil((event.ends - now) / DAY))
	if previewed == true then
		return math.max(1, days)
	end
	return days
end

-- The day number at `now` (days since the epoch, the day starting at `offsetHours` from midnight UTC).
function EventUtils.day(now: number, offsetHours: number): number
	return math.floor((now + offsetHours * 3600) / DAY)
end

return EventUtils
