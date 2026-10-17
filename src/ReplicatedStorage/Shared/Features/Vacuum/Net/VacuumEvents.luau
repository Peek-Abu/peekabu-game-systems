--!strict
--[=[
	VacuumEvents: the ByteNet packet contract for the vacuum (client -> server only). The client says where its camera
	looks while it holds the vacuum (VacuumMotionFormulas.encodeAim: whole 5-degree steps), at most
	VacuumMotionConstants.aim.rate times a second and only when it changes (reliable, so the last one always lands); the server checks it and puts it on the
	character for every client's aim layer (VacuumMotionSystem). Purely visual: suction targeting never reads it.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at VacuumServiceServer load).

	@class VacuumEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "VacuumEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local VacuumEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- The camera's look pitch, quantised (VacuumMotionFormulas.encodeAim).
			Aim = ByteNet.definePacket({
				value = ByteNet.uint8,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return VacuumEvents
