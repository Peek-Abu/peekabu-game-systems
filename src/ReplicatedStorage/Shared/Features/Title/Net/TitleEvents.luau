--!strict
--[=[
	TitleEvents: the ByteNet packet contract for titles requests (titles design spec, Decision 3).

	Client → owning server only. Equipping is a discrete REQUEST — ByteNet's sanctioned role. The
	resulting state change rides the charm-sync spine (StateSyncSliceRegistry's "titles"/"equippedTitle"
	atoms); nothing queryable moves over this packet.

	Payloads are `ByteNet.unknown` with the real shapes enforced by `TitleRequestRules` at the trust
	boundary (the AnimationEvents precedent).

	Boot-timing note (same as AnimationEvents): the client waits for the per-namespace replicated
	value the server creates when IT requires this module (at TitleServiceServer init).

	@class TitleEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "TitleEvents"

if not RunService:IsServer() then
	local storage = ReplicatedStorage:WaitForChild("BytenetStorage", 5)
	if storage then
		storage:WaitForChild(NAMESPACE, 5)
	else
		warn(`[TitleEvents] BytenetStorage not found after 5s — Titles equip requests will not send`)
	end
end

local TitleEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- client -> server: equip one of YOUR earned titles
			-- (shape: TitleRequestRules.EquipRequest)
			EquipRequest = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
		},
		-- Empty but present: `defineNamespace` types the closure return as the full namespaceData
		-- shape (the AnimationEvents/DebuggerEvents precedent).
		queries = {},
		structs = {},
	}
end)

return TitleEvents
