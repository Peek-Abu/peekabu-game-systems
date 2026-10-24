--!strict
--[=[
	CosmeticEvents: the ByteNet packets for cosmetic requests. Client → owning server only: equipping something
	and the first-join pick are discrete REQUESTS (ByteNet's sanctioned role); the resulting state rides the
	charm-sync spine (the `loadout` and `entitlements` atoms).

	Payloads are `ByteNet.unknown`; CosmeticRequestRules enforces the real shapes at the trust boundary.
	Boot timing as TitleEvents: the client waits for the namespace the server creates when it requires this module.

	@class CosmeticEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "CosmeticEvents"

if not RunService:IsServer() then
	local storage = ReplicatedStorage:WaitForChild("BytenetStorage", 5)
	if storage then
		storage:WaitForChild(NAMESPACE, 5)
	else
		warn(`[CosmeticEvents] BytenetStorage not found after 5s — cosmetic requests will not send`)
	end
end

local CosmeticEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- client -> server: change what you wear (shape: CosmeticTypes.Change)
			EquipRequest = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
			-- client -> server: items the player has now looked at (clears New!; shape: CosmeticRequestRules.SeenRequest)
			SeenRequest = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
			-- client -> server: the first-join pick (shape: CosmeticRequestRules.PickRequest)
			PickRequest = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return CosmeticEvents
