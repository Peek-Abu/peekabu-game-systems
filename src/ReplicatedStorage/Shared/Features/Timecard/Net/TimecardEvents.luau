--!strict
--[=[
	TimecardEvents: the punch request (client → server). The payload is unused; the server decides everything
	(the clock, RequestHandler rate limit, TimecardCalendarFormulas).

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module.

	@class TimecardEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "TimecardEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local TimecardEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			OpenClipboard = ByteNet.definePacket({ value = ByteNet.bool, reliabilityType = "reliable" }),
			Result = ByteNet.definePacket({ value = ByteNet.string, reliabilityType = "reliable" }),
			Punch = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return TimecardEvents
