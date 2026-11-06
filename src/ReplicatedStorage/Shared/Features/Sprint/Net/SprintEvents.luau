--!strict
--[=[
	SprintEvents: the ByteNet packet contract for sprinting. The client says whether the sprint key is held; the server
	decides whether that sprints, and sets the speed. The server sends each player their own stamina (whole percent,
	only when it changes): nobody else's client needs it, so it is not a replicated attribute.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at SprintServiceServer load).

	@class SprintEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "SprintEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local SprintEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- True while the sprint key (or the phone's SPRINT button) is held.
			Sprint = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- Server -> the owner only: their stamina, 0-100 (reliable: the last value, a full bar, must arrive).
			Stamina = ByteNet.definePacket({
				value = ByteNet.uint8,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return SprintEvents
