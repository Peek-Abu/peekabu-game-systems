--!strict
--[=[
	QueueTicketSystem: the departure ticket kept server to server. A departing server signs each party's ticket with the
	new reserved server's id (TeleportOptions.ReservedServerId, a GUID) and stores the ticket in a MemoryStore hash map
	under that id before anyone is teleported (`put`; a refused store fails the departure). On the reserved server, a
	joining player's carried ticket only names that key: `ready` looks the stored copy up (once per key, in the
	background, retried on QueueConstants.RETRY_DELAYS) and the arrival side waits for it, then `ticketOf` answers with
	QueueTeleportRules.pick, so the party list, capacity and perks come from the stored copy and an edited join-data
	ticket counts for nothing. Only a MemoryStore failure lets the carried copy stand. A return ticket (a trip home to
	a public server) is never stored and is read from the join data as before.

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
type StoredLookup = QueueTypes.StoredLookup

local log = Logger.new("QueueTicketSystem")

-- Each key's lookup: absent = not started, "pending" while it runs, else what it found.
local lookups: { [string]: StoredLookup | "pending" } = {}

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

local function carriedOf(player: Player): QueueTicket?
	return parse(player:GetJoinData().TeleportData)
end

-- Starts looking `key` up (once).
local function look(key: string)
	if lookups[key] ~= nil then
		return
	end
	lookups[key] = "pending"
	task.spawn(function()
		for attempt = 0, #QueueConstants.RETRY_DELAYS do
			if attempt > 0 then
				task.wait(QueueConstants.RETRY_DELAYS[attempt])
			end
			local ok, raw = pcall(function(): unknown
				return map():GetAsync(key)
			end)
			if ok then
				local stored = parse(raw)
				if stored == nil then
					log:warn(`no stored ticket under {key}: its carriers are treated as strangers`)
					lookups[key] = { status = "missing" }
				else
					lookups[key] = { status = "found", ticket = stored }
				end
				return
			end
			log:warn(`looking up the stored ticket failed: {tostring(raw)}`)
		end
		log:warn(`the ticket store is down: trusting carried tickets for {key}`)
		lookups[key] = { status = "error" }
	end)
end

local QueueTicketSystem = {}

--[=[
	Stores `data` (the ticket's JSON) under the reserved server id `key`. Yields; false (logged) when the store
	refused.
]=]
function QueueTicketSystem.put(key: string, data: string): boolean
	if key == "" then
		return false
	end
	local ok, err = pcall(function()
		map():SetAsync(key, data, QueueConstants.TICKET_SECONDS)
	end)
	if not ok then
		log:warn(`storing the ticket under {key} failed: {tostring(err)}`)
	end
	return ok
end

--[=[
	Whether `player`'s ticket can be judged now: true unless the stored copy their carried ticket names is still being
	looked up (the first call starts that lookup). Never yields.
]=]
function QueueTicketSystem.ready(player: Player): boolean
	local carried = carriedOf(player)
	local key = if carried ~= nil and carried.kind == "depart" then carried.server else nil
	if key == nil then
		return true
	end
	look(key)
	return lookups[key] ~= "pending"
end

--[=[
	The Queue ticket to believe for `player` (QueueTeleportRules.pick over their carried copy and its stored lookup).
]=]
function QueueTicketSystem.ticketOf(player: Player): QueueTicket?
	local carried = carriedOf(player)
	local key = if carried ~= nil then carried.server else nil
	local found = if key ~= nil then lookups[key] else nil
	local lookup: StoredLookup? = if type(found) == "table" then found else nil
	return QueueTeleportRules.pick(carried, lookup)
end

return QueueTicketSystem
