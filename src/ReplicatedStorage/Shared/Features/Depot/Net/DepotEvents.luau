--!strict
--[=[
	DepotEvents: the Depot's ByteNet packets: Card (server → client), a travel card with the contract's words, the quota and the truck number (the drive card when a
	party's truck leaves, the arrival card when it reaches the office; the client checks the kind,
	DepotStore.show), Board (server → client: open the contract board), Spot (server → client: a hub spot used) and Bell (server → all: a shift bell rang), LastShift (server → client: the
	returning player's last shift, for the board's card), and Ready (client → server), sent once the client is listening for cards, so the server
	holds a card until then (an arrival card can be sent before the client has loaded), and PickMap (client → server),
	a truck host's map pick.

	Boot-timing note (the CarryEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at DepotServiceServer load).

	@class DepotEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "DepotEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local DepotEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- kind "drive" | "arrival"; anything else is dropped by the client.
			Card = ByteNet.definePacket({
				value = ByteNet.struct({
					kind = ByteNet.string,
					client = ByteNet.string,
					job = ByteNet.string,
					note = ByteNet.string,
					-- The crew's quota (ShiftQuotaFormulas; 0 on the drive card) and a layout truck (1..DepotConstants.MAX_TRUCKS, 0 = unknown).
					quota = ByteNet.uint16,
					truck = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),
			-- To one player: open the contract board on this contract id (the board's prompt was used).
			Board = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
			-- To a returning player: their last shift, for the board's card (held until Ready, like Card).
			-- Counts are uint32: the card decode clamps them to 0..1,000,000, past what uint16 holds.
			LastShift = ByteNet.definePacket({
				value = ByteNet.struct({
					cleared = ByteNet.uint32,
					quota = ByteNet.uint32,
					bonus = ByteNet.uint32,
					catches = ByteNet.uint32,
					salvage = ByteNet.uint32,
					offered = ByteNet.uint32,
					quotaMet = ByteNet.bool,
					rating = ByteNet.string,
					truck = ByteNet.uint8,
				}),
				reliabilityType = "reliable",
			}),
			-- To one player: a hub spot they used (DepotSpotRules.open on the server, DepotSpotRules.decode on the
			-- client): what to open, and the standee's employee ("" for any other spot).
			Spot = ByteNet.definePacket({
				value = ByteNet.struct({
					spot = ByteNet.string,
					employee = ByteNet.string,
				}),
				reliabilityType = "reliable",
			}),
			-- To everyone: a shift bell rang here (its world position).
			Bell = ByteNet.definePacket({
				value = ByteNet.vec3,
				reliabilityType = "reliable",
			}),
			-- A truck host picks their truck's map ("office" | "school"; anything else is dropped). The server checks the
			-- sender hosts the truck they are aboard (DepotMapRules) and publishes the pick (DepotConstants.MAP_WORLD_ENTRY).
			PickMap = ByteNet.definePacket({
				value = ByteNet.string,
				reliabilityType = "reliable",
			}),
			-- Payload unused; the packet is the signal that this client now listens for Card.
			Ready = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return DepotEvents
