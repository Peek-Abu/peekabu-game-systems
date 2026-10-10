--!strict
--[=[
	CargoEvents: Cargo's ByteNet packets (client → server only). The server decides everything (what the
	sender holds, whether it fits a pocket, rate limits).

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at CargoServiceServer load).

	@class CargoEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "CargoEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local CargoEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Pocket the hands item. Payload unused; the packet is the request.
			Pocket = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return CargoEvents
