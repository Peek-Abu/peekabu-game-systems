--!strict
--[=[
	InteractionEvents: the ByteNet packets for channels (client → server only). The server re-checks
	everything: the target's ChannelKind, distance, the game's canChannel, rate limits.

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value
	the server creates when IT requires this module (at InteractionServiceServer load).

	@class InteractionEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "InteractionEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local InteractionEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- The object the player starts channeling (its ChannelKind decides the rules).
			ChannelStart = ByteNet.definePacket({
				value = ByteNet.inst,
				reliabilityType = "reliable",
			}),
			-- Payload unused; the packet is the request.
			ChannelStop = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return InteractionEvents
