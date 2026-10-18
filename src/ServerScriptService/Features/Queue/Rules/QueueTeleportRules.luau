--!strict
--[=[
	QueueTeleportRules: the retry schedule, the payload limits and the teleport ticket's wire format. Pure.

	A ticket travels as JSON teleport data. It goes through the client on the way, so it carries only what
	is harmless to forge (expected user ids, a match id, a result summary) and the arrival server decodes
	it as untrusted input. The reserved server's access code is what keeps strangers out.

	@class QueueTeleportRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

type WorldValue = WorldTypes.WorldValue
type WorldTable = WorldTypes.WorldTable
type QueuePayload = QueueTypes.QueuePayload
type QueueTicket = QueueTypes.QueueTicket

local QueueTeleportRules = {}

-- Seconds to wait before retrying after a player's `failures`-th failure, or nil: give up.
function QueueTeleportRules.retryDelay(failures: number): number?
	local delays = QueueConstants.RETRY_DELAYS
	if failures < 1 or failures > #delays then
		return nil
	end
	return delays[failures]
end

-- A checked copy of a payload, or nil and why. Absent = empty.
function QueueTeleportRules.payload(value: QueuePayload?): (QueuePayload?, string?)
	local result: QueuePayload = {}
	if value == nil then
		return result, nil
	end
	local count = 0
	for key, item in value do
		count += 1
		if count > QueueConstants.MAX_PAYLOAD_KEYS then
			return nil, `more than {QueueConstants.MAX_PAYLOAD_KEYS} keys`
		end
		if type(key) ~= "string" or key == "" or #key > QueueConstants.MAX_PAYLOAD_KEY_LENGTH then
			return nil, `bad key {tostring(key)}`
		end
		if type(item) ~= "string" and type(item) ~= "number" and type(item) ~= "boolean" then
			return nil, `"{key}" must be a string, number or boolean`
		end
		if type(item) == "string" and #item > QueueConstants.MAX_PAYLOAD_STRING then
			return nil, `"{key}" is longer than {QueueConstants.MAX_PAYLOAD_STRING} characters`
		end
		if type(item) == "number" and (item ~= item or math.abs(item) == math.huge) then
			return nil, `"{key}" is not a finite number`
		end
		result[key] = item
	end
	return result, nil
end

-- The ticket as plain data, ready for HttpService:JSONEncode.
function QueueTeleportRules.encode(ticket: QueueTicket): WorldTable
	local party: WorldTable = table.clone(ticket.party)
	local payload: WorldTable = table.clone(ticket.payload)
	local wire: WorldTable = {
		v = QueueConstants.TICKET_VERSION,
		kind = ticket.kind,
		role = ticket.role,
		capacity = ticket.capacity,
		party = party,
		payload = payload,
	}
	local from = ticket.from
	if from ~= nil then
		wire.from = from
	end
	return wire
end

local function kindOf(value: WorldValue?): QueueTypes.TicketKind?
	if value == "depart" then
		return "depart"
	elseif value == "return" then
		return "return"
	end
	return nil
end

-- A list of distinct positive whole user ids; absent decodes as empty.
local function userIds(value: WorldValue?): { number }?
	local result: { number } = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	local count = 0
	for _ in value do
		count += 1
	end
	if count > QueueConstants.MAX_CAPACITY then
		return nil
	end
	-- Every key 1..count present and nothing else: a list, not a dictionary or a list with holes.
	for index = 1, count do
		local item = value[index]
		if type(item) ~= "number" or item < 1 or item ~= math.floor(item) or table.find(result, item) ~= nil then
			return nil
		end
		table.insert(result, item)
	end
	return result
end

local function payloadOf(value: WorldValue?): QueuePayload?
	local result: QueuePayload = {}
	if value == nil then
		return result
	end
	if type(value) ~= "table" then
		return nil
	end
	for key, item in value do
		if type(key) ~= "string" or type(item) == "table" then
			return nil
		end
		result[key] = item
	end
	local checked = QueueTeleportRules.payload(result)
	return checked
end

--[=[
	Decodes teleport data (already JSON-decoded) into a ticket, or nil when it is not a valid one.
]=]
function QueueTeleportRules.decode(value: WorldValue?): QueueTicket?
	if type(value) ~= "table" or value.v ~= QueueConstants.TICKET_VERSION then
		return nil
	end
	-- Annotated and tested with `not` (the RoundSnapshotUtils note): comparing an optional singleton union
	-- against nil widens it back to string.
	local kind: QueueTypes.TicketKind? = kindOf(value.kind)
	local role = value.role
	local from = value.from
	local capacity = value.capacity
	if not kind then
		return nil
	end
	if type(role) ~= "string" or role == "" then
		return nil
	end
	if from ~= nil and type(from) ~= "string" then
		return nil
	end
	if
		type(capacity) ~= "number"
		or capacity < 1
		or capacity > QueueConstants.MAX_CAPACITY
		or capacity ~= math.floor(capacity)
	then
		return nil
	end
	local party = userIds(value.party)
	local payload = payloadOf(value.payload)
	if party == nil or payload == nil or #party > capacity then
		return nil
	end
	return {
		kind = kind,
		from = if type(from) == "string" then from else nil,
		role = role,
		party = party,
		capacity = capacity,
		payload = payload,
	}
end

return QueueTeleportRules
