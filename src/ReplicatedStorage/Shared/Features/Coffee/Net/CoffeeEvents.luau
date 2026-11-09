--!strict
--[=[
	CoffeeEvents: the ByteNet packet contract for Coffee for the crew. The client asks to spend one of its saved coffees
	(the FREE button); the server checks CoffeeRules.spends itself. The PA line is a server toast and the badge reads
	the CoffeeConstants.WORLD_ENTRY world entry, so nothing else is sent.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at CoffeeServiceServer load).

	@class CoffeeEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "CoffeeEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local CoffeeEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Client -> server: spend one of my saved coffees on this shift.
			Use = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return CoffeeEvents
