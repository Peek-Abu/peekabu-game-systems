--!strict
--[=[
	DepotEvents: the Depot's ByteNet packets: Card (server → client), a travel card (the drive card when a
	party's truck leaves, the arrival card when it reaches the office; the client checks the kind,
	DepotStore.show), and Ready (client → server), sent once the client is listening for cards, so the server
	holds a card until then (an arrival card can be sent before the client has loaded).

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at DepotServiceServer load).

	@class DepotEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "DepotEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local DepotEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- kind "drive" | "arrival"; anything else is dropped by the client.
			Card = ByteNet.definePacket({
				value = ByteNet.struct({
					kind = ByteNet.string,
					title = ByteNet.string,
					body = ByteNet.string,
				}),
				reliabilityType = "reliable",
			}),
			-- Payload unused; the packet is the signal that this client now listens for Card.
			Ready = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return DepotEvents
