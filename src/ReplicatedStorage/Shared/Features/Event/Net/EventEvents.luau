--!strict
--[=[
	EventEvents: the ByteNet packets for limited-time events. Server → client: what this player's finished shift paid
	in the event's money (the results screen's line). The money itself rides the charm-sync spine (`currency`). Boot
	timing as ShopEvents.

	@class EventEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "EventEvents"

if not RunService:IsServer() then
	local storage = ReplicatedStorage:WaitForChild("BytenetStorage", 5)
	if storage then
		storage:WaitForChild(NAMESPACE, 5)
	else
		warn(`[EventEvents] BytenetStorage not found after 5s — event pay will not show`)
	end
end

local EventEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- server -> client: { event, total, parts (EventTypes.PayPart list) }
			Paid = ByteNet.definePacket({
				value = ByteNet.struct({
					event = ByteNet.string,
					total = ByteNet.uint16,
					parts = ByteNet.array(ByteNet.string),
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return EventEvents
