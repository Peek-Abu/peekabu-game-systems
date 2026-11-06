--!strict
--[=[
	QueueTicketSystem: the departure ticket kept server to server. A departing server stores each party's ticket in a
	MemoryStore hash map under the id of the reserved server it reserved (`put`, before anyone is teleported), and that
	reserved server loads it once at boot (`prefetch`). `ticketOf` then answers with QueueTeleportRules.pick: the stored
	ticket over the copy the player carried in their join data, which passes through their client and could be edited
	(a longer party, a bigger capacity, someone else's perks). The carried copy is still read, as the fallback for an
	older hub build or a store outage, and for a trip home (a return ticket to a public server is never stored).

	Spec-exempt shell (MemoryStoreService, HttpService, join data); the choice is the specced QueueTeleportRules.pick
	and every ticket, stored or carried, goes through the specced QueueTeleportRules.decode.

	@class QueueTicketSystem
]=]

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local QueueTeleportRules = require(ServerScriptService.Features.Queue.Rules.QueueTeleportRules)

type QueueTicket = QueueTypes.QueueTicket

local log = Logger.new("QueueTicketSystem")

-- This reserved server's own stored ticket, once loaded (nil: none, not loaded yet, or not a reserved server).
local stored: QueueTicket? = nil

-- A ticket from its JSON, or nil (none, not JSON, or failing the decode checks).
local function parse(raw: unknown): QueueTicket?
	if type(raw) ~= "string" then
		return nil
	end
	local ok, parsed = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then
		return nil
	end
	-- JSONDecode is typed `any`; QueueTeleportRules.decode checks every field, so it is the trust boundary.
	local value: WorldTypes.WorldValue? = parsed
	return QueueTeleportRules.decode(value)
end

local function map(): MemoryStoreHashMap
	return MemoryStoreService:GetHashMap(QueueConstants.TICKET_MAP)
end

local QueueTicketSystem = {}

--[=[
	Stores `data` (the ticket's JSON) for the reserved server `serverId`. Yields; false (logged) when the store
	refused, in which case the arrival server falls back to the carried ticket.
]=]
function QueueTicketSystem.put(serverId: string, data: string): boolean
	if serverId == "" then
		return false
	end
	local ok, err = pcall(function()
		map():SetAsync(serverId, data, QueueConstants.TICKET_SECONDS)
	end)
	if not ok then
		log:warn(`storing the ticket for {serverId} failed: {tostring(err)}`)
	end
	return ok
end

--[=[
	Loads this reserved server's own ticket (`serverId` = game.PrivateServerId) in the background, retrying on
	QueueConstants.RETRY_DELAYS. Players who join before it lands are judged on their carried ticket.
]=]
function QueueTicketSystem.prefetch(serverId: string)
	if serverId == "" then
		return
	end
	task.spawn(function()
		for attempt = 0, #QueueConstants.RETRY_DELAYS do
			if attempt > 0 then
				task.wait(QueueConstants.RETRY_DELAYS[attempt])
			end
			local ok, raw = pcall(function(): unknown
				return map():GetAsync(serverId)
			end)
			if ok then
				stored = parse(raw)
				if stored == nil then
					log:info("no stored ticket for this server: carried tickets are used")
				end
				return
			end
			log:warn(`loading the stored ticket failed: {tostring(raw)}`)
		end
	end)
end

--[=[
	The Queue ticket to believe for `player`: this server's stored ticket over their carried one (QueueTeleportRules.pick).
]=]
function QueueTicketSystem.ticketOf(player: Player): QueueTicket?
	return QueueTeleportRules.pick(stored, parse(player:GetJoinData().TeleportData))
end

return QueueTicketSystem
