--!strict
--[=[
	The owner → server uplink packet (spec 2026-09-22 §6.3; Verdict: "uplink goes through an extended
	RequestHandler.wrap"; plan R2 Task 3).

	  u32 sentMs | u8 count | count × 16 B record      count 1–3, newest first

	`sentMs` is the owner's send time in session milliseconds (`GetServerTimeNow` minus the session epoch
	from the slot table). Each record's 10-bit `ageMs` is `sentMs − sample time`, so a sample's time is
	`sentMs − ageMs` — no 10-bit wrap, so an old sample can never alias into the future (the R1 review's
	alias item). The current sample comes first, then up to two previously SENT samples (redundancy: the
	packet survives two consecutive losses). A previous sample older than 1023 ms is left out.

	Decode-side checks (R1 review): the exact size is checked before anything is decoded; an owner may not
	set the action bit (actions are server-granted) or claim the ragdoll state (server-granted); ages must
	strictly increase (one sample time each). The server's send-time clock (`ReplicationUplinkRules.clockSeconds`)
	reads `sentMs` only after this passes.

	Pure.

	@class ReplicationUplinkCodec
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationRecordCodec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)

local ReplicationUplinkCodec = {}

local HEADER_BYTES = 5
local MAX_RECORDS = 3
local MAX_AGE_MS = 1023
local RECORD_BYTES = ReplicationRecordCodec.RECORD_BYTES

ReplicationUplinkCodec.HEADER_BYTES = HEADER_BYTES
ReplicationUplinkCodec.MAX_RECORDS = MAX_RECORDS
ReplicationUplinkCodec.MAX_AGE_MS = MAX_AGE_MS

export type UplinkSample = {
	record: ReplicationRecordCodec.Record,
	sampleMs: number,
}

export type Uplink = {
	sentMs: number,
	samples: { UplinkSample }, -- newest first
}

function ReplicationUplinkCodec.size(count: number): number
	return HEADER_BYTES + count * RECORD_BYTES
end

--[=[
	Encode `samples` (newest first; at least one). Writes each record's `ageMs` (the records belong to the
	sender). Stops at the first previous sample older than 1023 ms; the newest is always written.
]=]
function ReplicationUplinkCodec.encode(sentMs: number, samples: { UplinkSample }): buffer
	assert(#samples >= 1, "an uplink packet carries at least one sample")
	local count = 1
	for i = 2, math.min(#samples, MAX_RECORDS) do
		if sentMs - samples[i].sampleMs > MAX_AGE_MS then
			break
		end
		count = i
	end
	local b = buffer.create(ReplicationUplinkCodec.size(count))
	buffer.writeu32(b, 0, sentMs % 4294967296)
	buffer.writeu8(b, 4, count)
	for i = 1, count do
		local sample = samples[i]
		sample.record.ageMs = math.clamp(sentMs - sample.sampleMs, 0, MAX_AGE_MS)
		ReplicationRecordCodec.writeRecord(b, HEADER_BYTES + (i - 1) * RECORD_BYTES, sample.record)
	end
	return b
end

--[=[
	Validate and decode. Returns ok, a reason on failure, and the decoded packet on success — the shape
	`RequestHandler.wrap`'s `validate` expects, so the packet is decoded once.
]=]
function ReplicationUplinkCodec.decode(b: buffer): (boolean, string?, Uplink?)
	local length = buffer.len(b)
	if length < ReplicationUplinkCodec.size(1) or length > ReplicationUplinkCodec.size(MAX_RECORDS) then
		return false, "size", nil
	end
	local count = buffer.readu8(b, 4)
	if count < 1 or count > MAX_RECORDS or length ~= ReplicationUplinkCodec.size(count) then
		return false, "size", nil
	end
	local sentMs = buffer.readu32(b, 0)
	local samples: { UplinkSample } = table.create(count)
	local previousAge = -1
	for i = 1, count do
		local record = ReplicationRecordCodec.readRecord(b, HEADER_BYTES + (i - 1) * RECORD_BYTES)
		if record.hasAction then
			return false, "action", nil
		end
		if record.state == ReplicationRecordCodec.STATE_RAGDOLL then
			return false, "ragdoll", nil
		end
		if record.ageMs <= previousAge then
			return false, "order", nil
		end
		previousAge = record.ageMs
		samples[i] = { record = record, sampleMs = sentMs - record.ageMs }
	end
	return true, nil, { sentMs = sentMs, samples = samples }
end

return ReplicationUplinkCodec
