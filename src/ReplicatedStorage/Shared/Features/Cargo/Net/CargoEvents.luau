--!strict
--[=[
	CargoEvents: Cargo's ByteNet packets: requests (client → server; the server decides everything) and one
	announcement (`Banked`, server → all).

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at CargoServiceServer load).

	@class CargoEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "CargoEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local CargoEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Pocket the hands item. Payload unused; the packet is the request.
			Pocket = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- Swap the hands item with a pocket, or unpocket into empty hands (M2). Payload unused.
			Swap = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- Server → all: a Load landed (spec §7 "item swoops into the truck, cha-ching, '+15' floater"). The
			-- kinds loaded, where the swoop starts (the hands item, or the player), the bed's top, and the amounts
			-- credited (clearance, then the bonus after any overtime multiplier).
			Banked = ByteNet.definePacket({
				value = ByteNet.struct({
					kinds = ByteNet.array(ByteNet.string),
					from = ByteNet.vec3,
					to = ByteNet.vec3,
					clearance = ByteNet.uint16,
					bonus = ByteNet.uint16,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return CargoEvents
