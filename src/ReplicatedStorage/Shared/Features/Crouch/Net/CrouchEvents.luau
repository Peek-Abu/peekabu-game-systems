--!strict
--[=[
	CrouchEvents: the ByteNet packet contract for crouching (client → server only). The client says whether it wants
	to crouch (the key held, or a toggle on); the server decides whether that crouches, and sets the speed.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at CrouchServiceServer load).

	@class CrouchEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "CrouchEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local CrouchEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- True while the player wants to crouch (the key held, gamepad B or the phone's CROUCH toggled on).
			Crouch = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return CrouchEvents
