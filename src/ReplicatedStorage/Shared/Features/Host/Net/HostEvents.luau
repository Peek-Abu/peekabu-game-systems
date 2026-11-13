--!strict
--[=[
	HostEvents: the ByteNet packets a truck's crew sends (client → server). Start, Cancel and Leave carry nothing: the server finds the
	sender's truck (Queue's pad) and checks they may act (HostRules.canAct). Kick names the member (a UserId, float64
	because UserIds outgrow 32 bits); SetLock says on or off.

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value
	the server creates when IT requires this module (at HostServiceServer load).

	@class HostEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "HostEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local HostEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- The host starts the trip's countdown.
			Start = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- The host stops it.
			Cancel = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- A member steps out of the truck.
			Leave = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- The host takes a member off the truck until it leaves.
			Kick = ByteNet.definePacket({
				value = ByteNet.float64,
				reliabilityType = "reliable",
			}),
			-- The host turns friends only on or off.
			SetLock = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- The host opened (true) or closed the places menu: the idle start waits while it is open (capped).
			Browse = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return HostEvents
