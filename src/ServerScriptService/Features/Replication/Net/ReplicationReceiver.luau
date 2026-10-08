--!strict
--[=[
	ReplicationReceiver: wires ReplicationEvents' client → server packets to the service (plan R2
	Task 9): the uplink handler (built by ReplicationUplinkReceiver) and the `Ready` / `RespawnRequest` handlers behind
	RequestHandler rate limits. ByteNet listeners cannot be disconnected one by one, so they are connected
	once and route through replaceable handlers (`disconnect` drops the handlers).

	Spec-exempt shell (ByteNet).

	@class ReplicationReceiver
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicationEvents = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationEvents)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)

local ReplicationReceiver = {}

export type Handlers = {
	uplink: (data: buffer, player: Player) -> any,
	ready: (player: Player) -> (),
	respawnRequest: (player: Player) -> (),
}

local uplinkHandler: ((data: buffer, player: Player) -> any)? = nil
local readyHandler: ((data: boolean, player: Player) -> any)? = nil
local respawnHandler: ((data: boolean, player: Player) -> any)? = nil
local listening = false

function ReplicationReceiver.connect(handlers: Handlers)
	uplinkHandler = handlers.uplink
	readyHandler = RequestHandler.wrap({
		name = "CharacterReplicationReady",
		rateLimit = { maxRequests = 3, windowSeconds = 10 },
		handler = function(_data: boolean, player: Player)
			handlers.ready(player)
		end,
	})
	respawnHandler = RequestHandler.wrap({
		name = "CharacterRespawnRequest",
		rateLimit = { maxRequests = 2, windowSeconds = 5 },
		handler = function(_data: boolean, player: Player)
			handlers.respawnRequest(player)
		end,
	})
	if listening then
		return
	end
	listening = true
	local packets = ReplicationEvents.packets
	packets.Uplink.listen(function(data: buffer, player: Player?)
		local handler = uplinkHandler
		if player ~= nil and handler ~= nil then
			handler(data, player)
		end
	end)
	packets.Ready.listen(function(data: boolean, player: Player?)
		local handler = readyHandler
		if player ~= nil and handler ~= nil then
			handler(data, player)
		end
	end)
	packets.RespawnRequest.listen(function(data: boolean, player: Player?)
		local handler = respawnHandler
		if player ~= nil and handler ~= nil then
			handler(data, player)
		end
	end)
end

function ReplicationReceiver.disconnect()
	uplinkHandler = nil
	readyHandler = nil
	respawnHandler = nil
end

return ReplicationReceiver
