--!strict
--[=[
	ShiftEvents: the Shift's ByteNet packets (client → server only). The server parses the vote
	(ShiftVoteRules) and ignores it outside results, and accepts a platform report only from
	ShiftPlatformRules' fixed enum.

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at ShiftServiceServer load).

	@class ShiftEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "ShiftEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local ShiftEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- "another" or "depot"; anything else is dropped by the server.
			Vote = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
			-- The client's platform code (ShiftPlatformRules: 1 pc, 2 phone, 3 tablet, 4 console), analytics only;
			-- the server drops any other value and keeps the first valid report.
			Platform = ByteNet.definePacket({
				value = ByteNet.uint8,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return ShiftEvents
