--!strict
--[=[
	ShiftEvents: the Shift's ByteNet packets. Client → server: the server parses the vote (ShiftVoteRules) and
	ignores it outside results, accepts a platform report only from ShiftPlatformRules' fixed enum, and a transit
	ready report only for the sender's own hold. Server → client: EntranceFade, the office entrances' short black
	cover (OfficeEntranceSystem), drawn by the transit screen (ShiftTransitSystem).

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at ShiftServiceServer load).

	@class ShiftEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "ShiftEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local ShiftEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- "another" or "depot"; anything else is dropped by the server.
			Vote = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
			-- The client's platform code (ShiftPlatformRules: 1 pc, 2 phone, 3 tablet, 4 console), analytics only;
			-- the server drops any other value and keeps the first valid report.
			Platform = ByteNet.definePacket({
				value = ByteNet.uint8,
				reliabilityType = "reliable",
			}),
			-- The transit hold id this client is ready for (it sees the new office, placed, streamed in and lit); the
			-- server takes it only for the player's own built hold (ShiftTransitTracker.markReady).
			TransitReady = ByteNet.definePacket({
				value = ByteNet.uint32,
				reliabilityType = "reliable",
			}),
			-- server -> client: cover (true) or uncover (false) the screen in black over `seconds` (an office
			-- entrance's teleport, OfficeEntranceSystem).
			EntranceFade = ByteNet.definePacket({
				value = ByteNet.struct({
					covered = ByteNet.bool,
					seconds = ByteNet.float32,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return ShiftEvents
