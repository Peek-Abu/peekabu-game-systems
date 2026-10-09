--!strict
--[=[
	DailyRewardEvents: the claim request (client → server). The payload is unused; the server decides
	everything (RequestHandler rate limit, DailyRewardRules).

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated
	value the server creates when IT requires this module.

	@class DailyRewardEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "DailyRewardEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local DailyRewardEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			Claim = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return DailyRewardEvents
