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
			-- Choose a hotbar slot (1 = the vacuum, 2-5 the item slots); the server checks it and decides
			-- (CargoInventoryRules.selectPlan).
			Select = ByteNet.definePacket({
				value = ByteNet.uint8,
				reliabilityType = "reliable",
			}),
			-- Server → all: a Load landed (spec §7 "item swoops into the truck, cha-ching, '+15' floater"). The
			-- kinds loaded and aligned kit/proxy-size/rotation snapshots, where the swoop starts (the hands item, or the player), the bed's top, and the amounts
			-- credited (clearance, then the bonus after any overtime multiplier).
			Banked = ByteNet.definePacket({
				value = ByteNet.struct({
					kinds = ByteNet.array(ByteNet.string),
					visuals = ByteNet.array(
						ByteNet.struct({ kitId = ByteNet.string, proxySize = ByteNet.vec3, rotation = ByteNet.cframe })
					),
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
