--!strict
--[=[
	ReplicationUplinkRules: which owner samples enter a body (spec §6.3, Verdict "R2 must carry"; plan R2 Task 4).

	Per sample, oldest first (a packet carries the current sample and up to two previous ones):
	  wrongEpoch  its epoch (low 3 bits) is not the body's current epoch — a sample from the previous body
	  ahead       more than 64 ms after server time (owner clocks are synced by GetServerTimeNow)
	  stale       more than 1000 ms old, or older than the newest accepted and outside the dedupe window
	  duplicate   a time already accepted, same content (redundancy: expected, harmless)
	  mismatched  a time already accepted, DIFFERENT content: the first accepted version is final; this is
	              counted for the anti-cheat phase to judge
	  tooFast     under 15 ms after the newest accepted sample (the owner samples at most 60 Hz)
	  accepted    newer than everything accepted: it becomes the body's latest sample

	There is no uplink sequence number: a sample's time (`sentMs − ageMs`) is its identity, and dedupe
	compares the last 4 accepted samples' bytes with the 10-bit age masked out (the age differs per packet).
	The 1000 ms bound accepts the backlog an owner releases after a stall (Verdict) while keeping samples a
	1 s history could hold; the stricter §6.3 window and drift-slope check belong to the anti-cheat phase.

	Pure.

	@class ReplicationUplinkRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicationRecordCodec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)
local ReplicationUplinkCodec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationUplinkCodec)

local ReplicationUplinkRules = {}

local RING = 4
local MAX_AGE_MS = 1000
local MIN_SPACING_MS = 15
local AGE_RING = 120
local AHEAD_MS = ReplicationRecordCodec.OWNER_AHEAD_MS
-- Word 0 holds slot 7 · generation 2 · epoch 3 · age 10: clear bits 12–21 (the age) before comparing.
local AGE_MASK = bit32.bnot(bit32.lshift(1023, 12))

ReplicationUplinkRules.RING = RING
ReplicationUplinkRules.AGE_RING = AGE_RING
ReplicationUplinkRules.MAX_AGE_MS = MAX_AGE_MS
ReplicationUplinkRules.MIN_SPACING_MS = MIN_SPACING_MS
ReplicationUplinkRules.AHEAD_MS = AHEAD_MS

export type Counters = {
	accepted: number,
	duplicate: number,
	mismatched: number,
	stale: number,
	ahead: number,
	tooFast: number,
	wrongEpoch: number,
	lastAcceptedAgeMs: number, -- serverNow − sample time when the newest sample was accepted
	maxAcceptedAgeMs: number, -- the max of that over the last AGE_RING accepted samples
}

export type State = {
	epoch: number, -- the body's full epoch; samples must match its low 3 bits
	newestMs: number,
	ringTimes: { number }, -- RING accepted sample times (-math.huge = empty)
	ringWords: { number }, -- RING × 4 record words, age masked
	ringNext: number,
	latest: ReplicationRecordCodec.Record?,
	latestMs: number,
	fresh: boolean, -- set on accept; the fan-out clears it when it reads the sample
	counters: Counters,
	ageRing: { number }, -- AGE_RING ages at acceptance, preallocated
	ageNext: number,
}

function ReplicationUplinkRules.new(): State
	local state: State = {
		epoch = 0,
		newestMs = -math.huge,
		ringTimes = table.create(RING, -math.huge),
		ringWords = table.create(RING * 4, 0),
		ringNext = 1,
		latest = nil,
		latestMs = -math.huge,
		fresh = false,
		counters = {
			accepted = 0,
			duplicate = 0,
			mismatched = 0,
			stale = 0,
			ahead = 0,
			tooFast = 0,
			wrongEpoch = 0,
			lastAcceptedAgeMs = 0,
			maxAcceptedAgeMs = 0,
		},
		ageRing = table.create(AGE_RING, 0),
		ageNext = 1,
	}
	return state
end

--[=[
	A new body (spawn / respawn): adopt its epoch and forget the previous body's samples. Counters stay —
	they describe the player's link, not one body.
]=]
function ReplicationUplinkRules.reset(state: State, epoch: number)
	state.epoch = epoch
	state.newestMs = -math.huge
	for i = 1, RING do
		state.ringTimes[i] = -math.huge
	end
	state.ringNext = 1
	state.latest = nil
	state.latestMs = -math.huge
	state.fresh = false
end

--[=[
	The uplink rate limiter's clock: the owner's send time, never more than 64 ms past server time.
	`RequestHandler` never lets a bucket's clock move backwards, so a send time that steps back refills
	nothing.
]=]
function ReplicationUplinkRules.clockSeconds(sentMs: number, serverNowMs: number): number
	return math.min(sentMs, serverNowMs + AHEAD_MS) / 1000
end

local function findInRing(state: State, sampleMs: number): number?
	for i = 1, RING do
		if state.ringTimes[i] == sampleMs then
			return i
		end
	end
	return nil
end

local function wordAt(packet: buffer, offset: number, w: number): number
	local word = buffer.readu32(packet, offset + w * 4)
	return if w == 0 then bit32.band(word, AGE_MASK) else word
end

local function sameContent(state: State, ringSlot: number, packet: buffer, offset: number): boolean
	local base = (ringSlot - 1) * 4
	for w = 0, 3 do
		if state.ringWords[base + w + 1] ~= wordAt(packet, offset, w) then
			return false
		end
	end
	return true
end

-- Record the age at acceptance in the ring; no allocation. Max is computed at read time.
local function noteAge(state: State, ageMs: number)
	local ring = state.ageRing
	ring[state.ageNext] = ageMs
	state.ageNext = state.ageNext % AGE_RING + 1
	state.counters.lastAcceptedAgeMs = ageMs
end

local function remember(state: State, sampleMs: number, packet: buffer, offset: number)
	local ringSlot = state.ringNext
	state.ringTimes[ringSlot] = sampleMs
	local base = (ringSlot - 1) * 4
	for w = 0, 3 do
		state.ringWords[base + w + 1] = wordAt(packet, offset, w)
	end
	state.ringNext = ringSlot % RING + 1
end

--[=[
	Ingest one decoded uplink packet. `packet` is the raw buffer `uplink` was decoded from (for the byte
	comparison). Returns how many samples were accepted.
]=]
function ReplicationUplinkRules.ingest(
	state: State,
	packet: buffer,
	uplink: ReplicationUplinkCodec.Uplink,
	serverNowMs: number
): number
	local counters = state.counters
	local epochLow = state.epoch % 8
	local samples = uplink.samples
	local accepted = 0
	for i = #samples, 1, -1 do
		local sample = samples[i]
		local record = sample.record
		local sampleMs = sample.sampleMs
		local offset = ReplicationUplinkCodec.HEADER_BYTES + (i - 1) * ReplicationRecordCodec.RECORD_BYTES
		if record.epoch ~= epochLow then
			counters.wrongEpoch += 1
		elseif sampleMs > serverNowMs + AHEAD_MS then
			counters.ahead += 1
		elseif sampleMs < serverNowMs - MAX_AGE_MS then
			counters.stale += 1
		elseif sampleMs <= state.newestMs then
			local ringSlot = findInRing(state, sampleMs)
			if ringSlot == nil then
				counters.stale += 1
			elseif sameContent(state, ringSlot, packet, offset) then
				counters.duplicate += 1
			else
				counters.mismatched += 1
			end
		elseif sampleMs - state.newestMs < MIN_SPACING_MS then
			counters.tooFast += 1
		else
			state.newestMs = sampleMs
			remember(state, sampleMs, packet, offset)
			state.latest = record
			state.latestMs = sampleMs
			state.fresh = true
			counters.accepted += 1
			noteAge(state, serverNowMs - sampleMs)
			accepted += 1
		end
	end
	return accepted
end

--[=[
	Compute the maximum age of any accepted sample in the last AGE_RING slots.
	Called at read time by the debugger to avoid scanning the ring on every acceptance.
]=]
function ReplicationUplinkRules.maxAcceptedAgeMs(state: State): number
	local peak = 0
	for i = 1, AGE_RING do
		peak = math.max(peak, state.ageRing[i])
	end
	return peak
end

return ReplicationUplinkRules
