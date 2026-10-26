--!strict
--[=[
	LockerEvents: the ByteNet packets for the Lost & Found Lockers. Client → server: open a Locker, or (restricted
	from paid random items) buy one of its items directly. Server → client: what an open gave (the opening scene plays
	it), a refusal, and the player's restricted flag (sent on join, so the Locker screen shows the right buttons).
	Keys and pity ride the charm-sync spine (`lockers`); ownership rides `entitlements`.

	Payloads are `ByteNet.unknown` going up (LockerRequestRules enforces the shape) and typed coming down. Boot timing
	as ShopEvents.

	@class LockerEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "LockerEvents"

if not RunService:IsServer() then
	local storage = ReplicatedStorage:WaitForChild("BytenetStorage", 5)
	if storage then
		storage:WaitForChild(NAMESPACE, 5)
	else
		warn(`[LockerEvents] BytenetStorage not found after 5s — locker requests will not send`)
	end
end

local LockerEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- client -> server: { locker }
			OpenRequest = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
			-- client -> server: { locker, item }
			BuyRequest = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
			-- server -> client: what an open gave (LockerTypes.Outcome)
			Opened = ByteNet.definePacket({
				value = ByteNet.struct({
					locker = ByteNet.string,
					item = ByteNet.string,
					rarity = ByteNet.string,
					duplicate = ByteNet.bool,
					refund = ByteNet.uint32,
					guaranteed = ByteNet.bool,
					pity = ByteNet.uint16,
				}),
				reliabilityType = "reliable",
			}),
			-- server -> client: an open or buy was refused (reason: short / restricted / empty / locked / ...)
			Refused = ByteNet.definePacket({
				value = ByteNet.struct({
					locker = ByteNet.string,
					reason = ByteNet.string,
				}),
				reliabilityType = "reliable",
			}),
			-- server -> client: whether this player may open paid Lockers
			Status = ByteNet.definePacket({
				value = ByteNet.struct({
					restricted = ByteNet.bool,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return LockerEvents
