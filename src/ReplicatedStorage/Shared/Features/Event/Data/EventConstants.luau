--!strict
--[=[
	EventConstants: the names limited-time events use in the place (static; spec-exempt).

	- PREVIEW_ATTRIBUTE: a Workspace string attribute; an event id there shows that event as live on this server and
	  its clients at any time (the EventPreview admin command sets it; "" clears it).
	- PROP_TAG / PROP_ATTRIBUTE: a hub prop a builder tags `EventProp` and gives an `Event` attribute (the event id) is
	  shown only while that event is live (EventPropSystem); otherwise it waits in ServerStorage under HIDDEN_FOLDER.

	@class EventConstants
]=]

return table.freeze({
	PREVIEW_ATTRIBUTE = "EventPreview",
	PROP_TAG = "EventProp",
	PROP_ATTRIBUTE = "Event",
	HIDDEN_FOLDER = "HiddenEventProps",
	-- How often the props and the live event are looked at again (seconds).
	REFRESH_SECONDS = 30,
})
