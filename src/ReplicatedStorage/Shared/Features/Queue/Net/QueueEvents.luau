--!strict
--[=[
	QueueEvents: the ByteNet packet for Depart now (client → server). The payload is unused; the server
	finds the sender's pad and checks they are aboard an open pad (QueuePadTracker).

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value
	the server creates when IT requires this module (at QueueServiceServer load).

	@class QueueEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "QueueEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local QueueEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Payload unused; the packet is the request.
			Depart = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return QueueEvents
