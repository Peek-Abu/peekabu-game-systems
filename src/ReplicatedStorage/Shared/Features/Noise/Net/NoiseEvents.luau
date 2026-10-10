--!strict
--[=[
	NoiseEvents: the Noise feature's ByteNet packet (server → clients): a ripple to draw. The radius is
	already the heard radius (the noise's radius times Harlow's hearing scale).

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at NoiseServiceServer load).

	@class NoiseEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "NoiseEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local NoiseEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			Ripple = ByteNet.definePacket({
				value = ByteNet.struct({
					position = ByteNet.vec3,
					radius = ByteNet.float32,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return NoiseEvents
