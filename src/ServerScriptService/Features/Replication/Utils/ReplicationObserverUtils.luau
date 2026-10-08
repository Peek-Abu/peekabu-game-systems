--!strict
--[=[
	ReplicationObserverUtils: who can see what, read from the R2 relevant sets (character replication R3 spec,
	"observersOf / observersNear"). The answers every future body-tied or place-tied effect needs:

	- `observersOf` — the ready viewers that have a body loaded (its observers). Never the body's own
	  player: the owner sees its own rig, and callers add it when they mean "everyone who sees this body".
	- `observersNear` — the ready players with a live body within `radius` studs of a point (an explosion
	  here is seen by whoever is near enough to have this area loaded; pass the 600-stud relevance radius
	  for "anyone who could see it").
	- `sendToObservers` — one packet to a body's observers plus its own player (a hit spark on this body).

	Pure: reads the service's body and player maps, which are keyed by userId.

	@class ReplicationObserverUtils
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicationFanoutSystem = require(ServerScriptService.Features.Replication.Systems.ReplicationFanoutSystem)

type Body = ReplicationFanoutSystem.Body

local ReplicationObserverUtils = {}

-- Anything with a ByteNet packet's `sendTo` (a typed ByteNet packet is one).
export type Sendable<T> = { sendTo: (data: T, target: Player) -> () }

function ReplicationObserverUtils.observersOf(
	bodies: { [number]: Body },
	players: { [number]: Player },
	subjectUserId: number
): { Player }
	local out: { Player } = {}
	for userId, viewer in bodies do
		if userId ~= subjectUserId and viewer.ready and viewer.relevant[subjectUserId] then
			local player: Player? = players[userId]
			if player ~= nil then
				table.insert(out, player)
			end
		end
	end
	return out
end

function ReplicationObserverUtils.observersNear(
	bodies: { [number]: Body },
	players: { [number]: Player },
	position: Vector3,
	radius: number
): { Player }
	local out: { Player } = {}
	for userId, viewer in bodies do
		if viewer.ready and viewer.alive and (viewer.position - position).Magnitude <= radius then
			local player: Player? = players[userId]
			if player ~= nil then
				table.insert(out, player)
			end
		end
	end
	return out
end

--[=[
	Send `data` through `packet` to everyone who sees `player`'s body: its observers plus the player (once
	its client is ready, like `ReplicationBodyStateSender`'s audience). Returns how many received it.
]=]
function ReplicationObserverUtils.sendToObservers<T>(
	bodies: { [number]: Body },
	players: { [number]: Player },
	player: Player,
	packet: Sendable<T>,
	data: T
): number
	local targets = ReplicationObserverUtils.observersOf(bodies, players, player.UserId)
	local body = bodies[player.UserId]
	if body ~= nil and body.ready then
		table.insert(targets, player)
	end
	for _, target in targets do
		packet.sendTo(data, target)
	end
	return #targets
end

return ReplicationObserverUtils
