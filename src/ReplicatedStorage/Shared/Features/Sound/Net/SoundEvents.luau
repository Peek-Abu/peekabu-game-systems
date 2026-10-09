--!strict
--[=[
	SoundEvents: the ByteNet packet contract for sounds (server → client only).

	`Play` asks a client to play a REGISTERED sound id, positionally when `position` is set. The server
	validates the id before sending; the client re-checks it against its own registry and ignores an
	unknown one.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated
	value the server creates when IT requires this module (at SoundServiceServer load).

	@class SoundEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "SoundEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local SoundEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			Play = ByteNet.definePacket({
				value = ByteNet.struct({
					id = ByteNet.string,
					position = ByteNet.optional(ByteNet.vec3),
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return SoundEvents
