--!strict
--[=[
	SocialEvents: the social perks' requests (client → server). The payloads are unused; the server decides
	everything (RequestHandler rate limit, SocialRules).

	- CheckGroup: the group join prompt closed; the server checks membership and pays the one-time perk.
	- Asked: the favorite/like ask was shown; the server stores when, so it is spaced out.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated
	value the server creates when IT requires this module.

	@class SocialEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "SocialEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local SocialEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			CheckGroup = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			Asked = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return SocialEvents
