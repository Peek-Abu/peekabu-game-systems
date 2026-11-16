--!strict
--[=[
	EventStore: the client's limited-time event state. `paid` is what this player's last finished shift paid in the
	live event's money (EventEvents.Paid), for the results screen's line; nil until a shift pays it.

	@class EventStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type Paid = { event: string, total: number, parts: { string } }

local noPaid: Paid? = nil
local paid = Charm.atom(noPaid)

local EventStore = {
	paid = paid,
}

function EventStore.setPaid(value: Paid?)
	paid(value)
end

return EventStore
