--!strict
--[=[
	EventRegistry: the limited-time events, looked up by id. Turning an event on or off, or moving it, is a change to
	its `starts` / `ends` here: no code changes. Two events never overlap (EventRegistry.spec).

	harvest (the Thanksgiving launch event, owner picks r1 + answers 2026-11-16): "Thanksgiving Harvest", earned-only
	acorns; pay table R3; about one acorn pickup a shift worth 5; leftover acorns become Credits at 1 = 5 (R7); live Thu
	26 Nov 12:00 am ET to Sun 20 Dec 11:59 pm ET. The Gloom Locker key price is a placeholder until the owner sets
	prices (R4).

	@class EventRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventTypes = require(ReplicatedStorage.Shared.Features.Event.Data.EventTypes)

type Event = EventTypes.Event

local EVENTS: { Event } = {
	{
		id = "harvest",
		name = "Thanksgiving Harvest",
		short = "Harvest",
		currency = "acorns",
		-- 2026-11-26 05:00 UTC (12:00 am ET) to 2026-12-21 05:00 UTC (the end of Sun 20 Dec, ET).
		starts = 1795669200,
		ends = 1797829200,
		pay = { finished = 10, contract = 10, firstToday = 20, friend = 5 },
		convertTo = "credits",
		convertRate = 5,
		keys = { { locker = "gloom", price = 60 } },
		pickup = { amount = 5, firstPile = 3, lastPile = 15 },
	},
}

local byId: { [string]: Event } = {}
for _, event in EVENTS do
	assert(byId[event.id] == nil, `EventRegistry: duplicate id {event.id}`)
	table.freeze(event.pay)
	table.freeze(event.pickup)
	for _, key in event.keys do
		table.freeze(key)
	end
	table.freeze(event.keys)
	byId[event.id] = table.freeze(event)
end
table.freeze(EVENTS)

local EventRegistry = {}

function EventRegistry.get(id: string): Event?
	return byId[id]
end

function EventRegistry.all(): { Event }
	return EVENTS
end

return EventRegistry
