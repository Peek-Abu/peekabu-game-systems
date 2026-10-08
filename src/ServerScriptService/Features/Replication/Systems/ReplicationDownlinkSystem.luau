--!strict
--[=[
	ReplicationDownlinkSystem: what one viewer receives in one frame (spec §6.4 as superseded by the Verdict's v3
	send policy and its "Downlink scheduling is a priority accumulator" decision; plan R2 Task 6).

	`encode` writes a body's newest accepted sample ONCE per frame (the fan-out reuses the bytes for every
	viewer): slot, slot generation, the epoch's low bits, and the age at batch time. Restamp (R1 review): the
	10-bit age saturates at 1023 ms, so a sample older than that — a body that stopped sending, typically
	standing still — goes out with age 0 and zero velocity: "still here as of now". Viewers receive it as a
	new sample with transit-only lateness and hold the body.

	`pack` builds the viewer's batch from the candidates due this frame (scheduled by their body's send
	policy, or pending from a frame where they were not sent):
	  - far cap: a body beyond `farCapStuds` whose last record to this viewer went out less than
	    `farMinIntervalMs` ago is held this frame (about 30 Hz at most, the floor the single render delay
	    covers). It stays due and keeps its score; it does not accumulate while held;
	  - every other due body's score (per viewer, per body) grows by its closeness weight: `nearWeight`
	    within `nearStuds`, falling linearly to `farWeight` at `farStuds`. Bodies that are not due never
	    accumulate;
	  - if every due record fits — at most 700 B (hard cap) and within the viewer's 24 KB/s budget (an
	    allowance refilled per ms, capped at 700 B) — all of them go, with no ordering at all;
	  - otherwise the highest scores fill the batch (see `selectTop`). Near bodies go first in a crowd, and a
	    far body still climbs every frame until it outranks them, so nothing starves;
	  - a sent body's score resets to 0; every due body that is not sent becomes pending: it stays due (it
	    keeps being a candidate even if its body stopped changing) until it is sent.

	Pure. No allocation per frame in steady state except the batch buffer itself: scores, last-send times
	and the selection arrays are reused per viewer.

	@class ReplicationDownlinkSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicationRecordCodec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)

local ReplicationDownlinkSystem = {}

local HARD_CAP_BYTES = 700
local BUDGET_BYTES_PER_SECOND = 24000
local HEADER_BYTES = ReplicationRecordCodec.HEADER_BYTES
local MIN_RECORD_BYTES = ReplicationRecordCodec.RECORD_BYTES
local MAX_AGE_MS = 1023

ReplicationDownlinkSystem.HARD_CAP_BYTES = HARD_CAP_BYTES
ReplicationDownlinkSystem.BUDGET_BYTES_PER_SECOND = BUDGET_BYTES_PER_SECOND
-- Room for a record with its action extension (R3), so a body's scratch buffer never needs resizing.
ReplicationDownlinkSystem.SCRATCH_BYTES = ReplicationRecordCodec.RECORD_BYTES + ReplicationRecordCodec.ACTION_BYTES

export type Config = {
	nearStuds: number, -- within this, a due body gains `nearWeight` per frame
	nearWeight: number,
	farStuds: number, -- at and beyond this, `farWeight` per frame (linear in between)
	farWeight: number,
	farCapStuds: number, -- beyond this, at most one record per `farMinIntervalMs` to this viewer
	farMinIntervalMs: number,
}

-- Starting values; R2's last task measures them (Verdict: all numbers are config).
local DEFAULT_CONFIG: Config = {
	nearStuds = 50,
	nearWeight = 3,
	farStuds = 600,
	farWeight = 1,
	farCapStuds = 300,
	farMinIntervalMs = 33,
}
table.freeze(DEFAULT_CONFIG)
ReplicationDownlinkSystem.DEFAULT_CONFIG = DEFAULT_CONFIG

export type Viewer = {
	seq: number,
	allowanceBytes: number,
	lastPackMs: number?,
	config: Config,
	pending: { [number]: boolean }, -- slot → was due and not sent; due until sent
	scores: { [number]: number }, -- slot → accumulated priority; 0 after a send
	lastSentMs: { [number]: number }, -- slot → when its last record went to this viewer (the far cap)
	eligible: { number }, -- scratch: this frame's due slots not held by the far cap (permuted by selection)
	chosen: { number }, -- scratch: the slots kept this frame when not everything fits
	sentBytes: number,
	sentBatches: number,
}

function ReplicationDownlinkSystem.newViewer(config: Config?): Viewer
	return {
		seq = 0,
		allowanceBytes = HARD_CAP_BYTES,
		lastPackMs = nil,
		config = config or DEFAULT_CONFIG,
		pending = {},
		scores = {},
		lastSentMs = {},
		eligible = {},
		chosen = {},
		sentBytes = 0,
		sentBatches = 0,
	}
end

-- A body left this viewer's set: it owes nothing, and a later re-entry starts from a clean score.
function ReplicationDownlinkSystem.forget(viewer: Viewer, slot: number)
	viewer.pending[slot] = nil
	viewer.scores[slot] = nil
	viewer.lastSentMs[slot] = nil
end

-- What a due body at `distance` studs gains per frame.
function ReplicationDownlinkSystem.closeness(config: Config, distance: number): number
	if distance <= config.nearStuds then
		return config.nearWeight
	elseif distance >= config.farStuds then
		return config.farWeight
	end
	local t = (distance - config.nearStuds) / (config.farStuds - config.nearStuds)
	return config.nearWeight + (config.farWeight - config.nearWeight) * t
end

-- One scratch record reused for every encode: no table per body per frame.
local scratch: ReplicationRecordCodec.Record = {
	slot = 0,
	generation = 0,
	epoch = 0,
	ageMs = 0,
	position = Vector3.zero,
	yaw = 0,
	pitch = 0,
	velocity = Vector3.zero,
	state = 0,
	grounded = true,
	hasAction = false,
	rotation = nil,
}

function ReplicationDownlinkSystem.encode(
	out: buffer,
	slot: number,
	generation: number,
	epoch: number,
	record: ReplicationRecordCodec.Record,
	sampleMs: number,
	batchTimeMs: number
): number
	local ageMs = batchTimeMs - sampleMs
	local velocity = record.velocity
	if ageMs > MAX_AGE_MS then
		ageMs = 0
		velocity = Vector3.zero
	elseif ageMs < 0 then
		ageMs = 0
	end
	scratch.slot = slot
	scratch.generation = generation
	scratch.epoch = epoch
	scratch.ageMs = ageMs
	scratch.position = record.position
	scratch.yaw = record.yaw
	scratch.pitch = record.pitch
	scratch.velocity = velocity
	scratch.state = record.state
	scratch.grounded = record.grounded
	scratch.hasAction = false -- R2 relays no actions (they are server-granted, R3)
	scratch.rotation = record.rotation
	ReplicationRecordCodec.writeRecord(out, 0, scratch)
	return ReplicationRecordCodec.RECORD_BYTES
end

-- Higher score first; equal scores go to the lower slot, so the order is deterministic.
local function outranks(scores: { [number]: number }, a: number, b: number): boolean
	local scoreA, scoreB = scores[a], scores[b]
	return scoreA > scoreB or (scoreA == scoreB and a < b)
end

local function siftDown(heap: { number }, scores: { [number]: number }, index: number, size: number)
	while true do
		local best = index * 2
		if best > size then
			return
		end
		if best < size and outranks(scores, heap[best + 1], heap[best]) then
			best += 1
		end
		if not outranks(scores, heap[best], heap[index]) then
			return
		end
		heap[index], heap[best] = heap[best], heap[index]
		index = best
	end
end

--[=[
	Over the limit: keep the highest scores that fit `budget`, into `viewer.chosen`. Returns the batch size.

	A binary max-heap built in place over the reused `eligible` array and popped only until the batch is
	full: O(n + k log n), under ~900 comparisons for n = 128 candidates and k = 43 picks, against ~5,000 for
	a repeated max-scan. Unlike `table.sort` it orders only what is sent and needs no comparator closure over
	the scores (an allocation per call). Records of different sizes (R3's action extension) are handled
	greedily: one that does not fit is skipped and a smaller one behind it may still go.
]=]
local function selectTop(viewer: Viewer, lengths: { [number]: number }, budget: number): number
	local heap = viewer.eligible
	local scores = viewer.scores
	local pending = viewer.pending
	local chosen = viewer.chosen
	table.clear(chosen)
	local size = #heap
	for i = 1, size do
		pending[heap[i]] = true -- cleared again for every slot that is sent
	end
	for i = size // 2, 1, -1 do
		siftDown(heap, scores, i, size)
	end
	local total = HEADER_BYTES
	while size > 0 and budget - total >= MIN_RECORD_BYTES do
		local top = heap[1]
		heap[1] = heap[size]
		size -= 1
		siftDown(heap, scores, 1, size)
		local length = lengths[top]
		if total + length <= budget then
			total += length
			table.insert(chosen, top)
		end
	end
	return total
end

--[=[
	Build this viewer's batch. `slots` holds the due slots and `distances[i]` is the distance in studs from
	the viewer to the body in `slots[i]`; `bytes[slot]` and `lengths[slot]` are this frame's encodings.
	`nowMs` is also the batch time. Returns nil when nothing is sent.
]=]
function ReplicationDownlinkSystem.pack(
	viewer: Viewer,
	nowMs: number,
	slots: { number },
	bytes: { [number]: buffer },
	lengths: { [number]: number },
	distances: { number }
): buffer?
	local lastPack = viewer.lastPackMs
	if lastPack ~= nil then
		local refill = BUDGET_BYTES_PER_SECOND * math.max(0, nowMs - lastPack) / 1000
		viewer.allowanceBytes = math.min(HARD_CAP_BYTES, viewer.allowanceBytes + refill)
	end
	viewer.lastPackMs = nowMs
	local count = #slots
	if count == 0 then
		return nil
	end
	local config = viewer.config
	local scores = viewer.scores
	local lastSentMs = viewer.lastSentMs
	local pending = viewer.pending
	local eligible = viewer.eligible
	table.clear(eligible)
	local total = HEADER_BYTES
	for i = 1, count do
		local slot = slots[i]
		local distance = distances[i]
		local lastSent = lastSentMs[slot]
		if distance > config.farCapStuds and lastSent ~= nil and nowMs - lastSent < config.farMinIntervalMs then
			pending[slot] = true
		else
			scores[slot] = (scores[slot] or 0) + ReplicationDownlinkSystem.closeness(config, distance)
			table.insert(eligible, slot)
			total += lengths[slot]
		end
	end
	local budget = math.min(HARD_CAP_BYTES, viewer.allowanceBytes)
	local kept = eligible
	if total > budget then
		total = selectTop(viewer, lengths, budget)
		kept = viewer.chosen
	end
	if #kept == 0 then
		return nil
	end
	viewer.seq = (viewer.seq + 1) % 65536
	local batch = buffer.create(total)
	buffer.writeu16(batch, 0, viewer.seq)
	buffer.writeu32(batch, 2, nowMs % 4294967296)
	buffer.writeu8(batch, 6, #kept)
	local offset = HEADER_BYTES
	for _, slot in kept do
		local length = lengths[slot]
		buffer.copy(batch, offset, bytes[slot], 0, length)
		offset += length
		pending[slot] = nil
		scores[slot] = 0
		lastSentMs[slot] = nowMs
	end
	viewer.allowanceBytes -= total
	viewer.sentBytes += total
	viewer.sentBatches += 1
	return batch
end

return ReplicationDownlinkSystem
