--!strict
--[=[
	ReplicationSlotSender: tells viewers which body holds which slot.

	A slot entry announces a body taking a slot, or releasing it, to every viewer that has finished its
	handshake (`ready`). Deciding who receives a slot update is a Sender's job, so it lives here rather
	than in ReplicationServiceServer, which calls it on spawn, respawn and leave (issue #37). The packet
	is passed in, like ReplicationObserverUtils.sendToObservers, so a spec can record the sends.

	@class ReplicationSlotSender
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local ReplicationFanoutSystem = require(ServerScriptService.Features.Replication.Systems.ReplicationFanoutSystem)
local ReplicationObserverUtils = require(ServerScriptService.Features.Replication.Utils.ReplicationObserverUtils)

type Body = ReplicationFanoutSystem.Body

-- One row of the slot table, as the `SlotEntry` packet carries it.
export type SlotEntry = {
	slot: number,
	userId: number,
	generation: number,
	epoch: number,
	active: boolean,
}

local ReplicationSlotSender = {}

--[=[
	The slot-table row a viewer receives for `body`.
	@param body Body
	@param active boolean -- false when the body is releasing its slot
	@return SlotEntry
]=]
function ReplicationSlotSender.entryOf(body: Body, active: boolean): SlotEntry
	return {
		slot = body.slot,
		userId = body.userId,
		generation = body.generation,
		epoch = body.epoch.value,
		active = active,
	}
end

--[=[
	Sends `body`'s slot entry through `packet` to every ready viewer that is still a connected player.
	@param packet ReplicationObserverUtils.Sendable<SlotEntry>
	@param body Body
	@param active boolean
	@param bodiesByUserId { [number]: Body }
	@param playersByUserId { [number]: Player }
]=]
function ReplicationSlotSender.broadcast(
	packet: ReplicationObserverUtils.Sendable<SlotEntry>,
	body: Body,
	active: boolean,
	bodiesByUserId: { [number]: Body },
	playersByUserId: { [number]: Player }
)
	local entry = ReplicationSlotSender.entryOf(body, active)
	for userId, other in bodiesByUserId do
		local player: Player? = playersByUserId[userId]
		if other.ready and player ~= nil then
			packet.sendTo(entry, player)
		end
	end
end

return ReplicationSlotSender
