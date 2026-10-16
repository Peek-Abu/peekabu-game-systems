--!strict
--[=[
	HideEvents: the ByteNet packet contract for hiding (client → server only). Going in is the spot's prompt (the
	server's Triggered); coming out is this request. The server decides everything.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at HideServiceServer load).

	@class HideEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "HideEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local HideEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Payload unused; the packet is the request to come out.
			Exit = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return HideEvents
