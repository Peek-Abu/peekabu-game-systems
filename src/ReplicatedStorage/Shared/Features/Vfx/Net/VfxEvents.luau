--!strict
--[=[
	VfxEvents: the ByteNet packet contract for VFX (server → client only).

	- `PlayRecipe`: play a REGISTERED recipe at a CFrame (the client re-checks the id).
	- `SetAtmosphere`: blend to a REGISTERED atmosphere preset, or back to the place's own Lighting
	  (`id` absent), over `fade` seconds.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated
	value the server creates when IT requires this module (at VfxServiceServer load).

	@class VfxEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "VfxEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local VfxEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			PlayRecipe = ByteNet.definePacket({
				value = ByteNet.struct({
					id = ByteNet.string,
					cframe = ByteNet.cframe,
				}),
				reliabilityType = "reliable",
			}),
			SetAtmosphere = ByteNet.definePacket({
				value = ByteNet.struct({
					id = ByteNet.optional(ByteNet.string),
					fade = ByteNet.float32,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return VfxEvents
