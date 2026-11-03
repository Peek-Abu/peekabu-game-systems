--!strict
--[=[
	AbilityEvents: the ByteNet packet contract for employee abilities. The client only asks (`Use`: the ability button;
	`Cancel`: end a Potted Plant now, on its move or action input); the server decides everything and tells the user
	alone what Spot It! found (`Spotted`: the treasure's CargoId).

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at AbilityServiceServer load).

	@class AbilityEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "AbilityEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local AbilityEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- The ability button was pressed (the value is unused).
			Use = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- End my Potted Plant now (the value is unused).
			Cancel = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- Server -> the Spot It! user only: the treasure to show.
			Spotted = ByteNet.definePacket({
				value = ByteNet.struct({
					cargoId = ByteNet.uint32,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return AbilityEvents
