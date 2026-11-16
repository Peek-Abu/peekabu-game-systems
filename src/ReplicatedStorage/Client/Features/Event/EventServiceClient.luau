--!strict
--[=[
	EventServiceClient: limited-time events on the client. `live()` is the event live now on the server's clock (or the
	admin preview, the Workspace EventPreview attribute the server sets), the same answer the server gives
	(EventUtils.live). It keeps what this player's last shift paid in the event's money (EventEvents.Paid) in
	EventStore for the results screen.

	@class EventServiceClient
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EventShared = ReplicatedStorage.Shared.Features.Event
local EventConstants = require(EventShared.Data.EventConstants)
local EventEvents = require(EventShared.Net.EventEvents)
local EventRegistry = require(EventShared.Data.EventRegistry)
local EventTypes = require(EventShared.Data.EventTypes)
local EventUtils = require(EventShared.Utils.EventUtils)
local EventStore = require(ReplicatedStorage.Client.Features.Event.State.EventStore)

local stoppers: { () -> () } = {}

local function preview(): string?
	local value = Workspace:GetAttribute(EventConstants.PREVIEW_ATTRIBUTE)
	return if type(value) == "string" and value ~= "" then value else nil
end

export type EventServiceClient = {
	dependencies: { string },
	init: (self: EventServiceClient) -> (),
	stop: (self: EventServiceClient) -> (),
	-- The event live now (dates or admin preview), or nil.
	live: (self: EventServiceClient) -> EventTypes.Event?,
	-- Whole days the live event has left (1 at least while previewed); 0 when none is live.
	daysLeft: (self: EventServiceClient) -> number,
}

local EventServiceClient: EventServiceClient = {
	dependencies = {},

	init = function(_self)
		table.insert(
			stoppers,
			EventEvents.packets.Paid.listen(function(data: { event: string, total: number, parts: { string } })
				EventStore.setPaid({ event = data.event, total = data.total, parts = data.parts })
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	live = function(_self)
		return EventUtils.live(EventRegistry.all(), Workspace:GetServerTimeNow(), preview())
	end,

	daysLeft = function(self)
		local event = self:live()
		if event == nil then
			return 0
		end
		return EventUtils.daysLeft(event, Workspace:GetServerTimeNow(), preview() == event.id)
	end,
}

return EventServiceClient
