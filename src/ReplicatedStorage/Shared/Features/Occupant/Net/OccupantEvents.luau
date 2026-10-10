--!strict
--[=[
	OccupantEvents: Mr. Harlow's ByteNet packets (server → clients only): the caught player's camera snap to his
	face, the lights dying around a catch, and every light flickering when a pressure tier rises. Everything
	else (his "?" / "!", his speech bubble, his mode for the heartbeat) rides replicated Instances and
	attributes.

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at OccupantServiceServer load).

	@class OccupantEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "OccupantEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local OccupantEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- To the caught player: where their camera looks (at his face) for SNAP_SECONDS.
			CatchCam = ByteNet.definePacket({
				value = ByteNet.cframe,
				reliabilityType = "reliable",
			}),
			-- To everyone: the lights within LIGHTS_OUT_RADIUS of this point die for LIGHTS_OUT_SECONDS.
			LightsOut = ByteNet.definePacket({
				value = ByteNet.vec3,
				reliabilityType = "reliable",
			}),
			-- To everyone: a pressure tier rose; every light flickers for TIER_FLICKER_SECONDS.
			Flicker = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return OccupantEvents
