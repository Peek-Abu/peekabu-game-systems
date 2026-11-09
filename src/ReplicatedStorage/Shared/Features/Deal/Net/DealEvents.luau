--!strict
--[=[
	DealEvents: the ByteNet packet contract for the one-time deals. The client asks to spend a waiting pick on one
	choice (the chooser); the server checks DealRules.canChoose itself and grants through the cosmetic reveal, so
	nothing comes back here.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at DealServiceServer load).

	@class DealEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "DealEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local DealEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Client -> server: spend my waiting pick in `deal` on `choice`.
			Choose = ByteNet.definePacket({
				value = ByteNet.struct({
					deal = ByteNet.string,
					choice = ByteNet.string,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return DealEvents
