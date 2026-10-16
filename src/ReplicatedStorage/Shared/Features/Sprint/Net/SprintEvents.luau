--!strict
--[=[
	SprintEvents: the ByteNet packet contract for sprinting (client → server only). The client says whether the sprint
	key is held; the server decides whether that sprints, and sets the speed.

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
		},
		queries = {},
		structs = {},
	}
end)

return SprintEvents
