--!strict
--[=[
	ReplicationUplinkReceiver: the uplink packet handler (Verdict: "Uplink goes through an extended
	RequestHandler.wrap"; plan R2 Task 4).

	  validate  ReplicationUplinkCodec.decode — exact size, no action bit, no ragdoll, ordered ages. The
	            decoded packet is handed to the handler (decoded once).
	  clock     ReplicationUplinkRules.clockSeconds(sentMs, now): the bucket refills by the owner's send times, so a
	            backlog released after a stall pays for itself, while a flood stamped with one send time
	            gets at most a bucket's worth through (developer run: arrival-paced limits dropped an
	            honest backlog as Flood).
	  bucket    10 tokens, refilled 60 per second of send time.
	  onReject  "count": drops are counted per player for the Debugger, never a warning each.
	  handler   ReplicationUplinkRules.ingest on the player's current body; `onAccepted` when a sample got in.

	Shared by ReplicationServiceServer and the load measurement, so both run the same path.

	@class ReplicationUplinkReceiver
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicationUplinkCodec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationUplinkCodec)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local ReplicationUplinkRules = require(ServerScriptService.Features.Replication.Rules.ReplicationUplinkRules)

local ReplicationUplinkReceiver = {}

ReplicationUplinkReceiver.ACTION = "CharacterUplink"
ReplicationUplinkReceiver.BUCKET = 10
ReplicationUplinkReceiver.REFILL_PER_SECOND = 60

--[=[
	@param resolve -- the player's live body ingest state, or nil (no body / dead)
	@param nowMs -- server session time in ms
	@param onAccepted -- called after a packet put at least one sample into the body
	@return the wrapped handler for `ReplicationEvents.packets.Uplink`
]=]
function ReplicationUplinkReceiver.wrap(
	resolve: (player: Player) -> ReplicationUplinkRules.State?,
	nowMs: () -> number,
	onAccepted: (player: Player, state: ReplicationUplinkRules.State) -> ()
): (data: buffer, player: Player) -> unknown
	return RequestHandler.wrap({
		name = ReplicationUplinkReceiver.ACTION,
		rateLimit = {
			maxRequests = ReplicationUplinkReceiver.BUCKET,
			windowSeconds = ReplicationUplinkReceiver.BUCKET / ReplicationUplinkReceiver.REFILL_PER_SECOND,
		},
		validate = function(data: buffer, _player: Player): (boolean, string?, ReplicationUplinkCodec.Uplink?)
			return ReplicationUplinkCodec.decode(data)
		end,
		clock = function(data: buffer, _player: Player): number
			-- Safe: validation already proved the packet holds at least the 5-byte header.
			return ReplicationUplinkRules.clockSeconds(buffer.readu32(data, 0), nowMs())
		end,
		onReject = "count",
		handler = function(data: buffer, player: Player, uplink: ReplicationUplinkCodec.Uplink?)
			local state = resolve(player)
			if uplink == nil or state == nil then
				return
			end
			if ReplicationUplinkRules.ingest(state, data, uplink, nowMs()) > 0 then
				onAccepted(player, state)
			end
		end,
	})
end

return ReplicationUplinkReceiver
