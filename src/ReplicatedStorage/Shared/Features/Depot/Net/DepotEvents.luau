--!strict
--[=[
	DepotEvents: the Depot's ByteNet packet (server → client only): a travel card (the drive card when a
	party's truck leaves, the arrival card when it reaches the office). The client checks the kind
	(DepotStore.show).

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
		},
		queries = {},
		structs = {},
	}
end)

return DepotEvents
