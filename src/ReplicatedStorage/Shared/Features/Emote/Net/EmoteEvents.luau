--!strict
--[=[
	EmoteEvents: the ByteNet packets for emotes. Client -> owning server only: play the emote in a wheel slot, or stop
	the one playing. What everyone sees is the replicated animation (AnimationServiceServer), so nothing goes back.

	Payloads are `ByteNet.unknown`; EmoteRequestRules enforces the shapes at the trust boundary.

	@class EmoteEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "EmoteEvents"

if not RunService:IsServer() then
	local storage = ReplicatedStorage:WaitForChild("BytenetStorage", 5)
	if storage then
		storage:WaitForChild(NAMESPACE, 5)
	else
		warn(`[EmoteEvents] BytenetStorage not found after 5s — emote requests will not send`)
	end
end

local EmoteEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- client -> server: play the emote in this wheel slot (shape: EmoteRequestRules.PlayRequest)
			PlayRequest = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
			-- client -> server: stop my emote (I moved)
			StopRequest = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return EmoteEvents
