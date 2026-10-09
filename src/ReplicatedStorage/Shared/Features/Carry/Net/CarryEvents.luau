--!strict
--[=[
	CarryEvents: the ByteNet packet contract for carrying (client → server only). The server validates
	everything (RequestHandler rate limits, a well-formed aim, that the sender actually carries
	something).

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated
	value the server creates when IT requires this module (at CarryServiceServer load).

	@class CarryEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "CarryEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local CarryEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Payload unused; the packet is the request.
			Drop = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- The aim (the client's camera look direction); normalized and checked on the server.
			Throw = ByteNet.definePacket({
				value = ByteNet.vec3,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return CarryEvents
