--!strict
--[=[
	Character record codec (spec 2026-09-22 §6.2; measured in the spike's CP0 and A/B).

	The v2 16-byte character record from spec §6.2, bit-packed into four u32 words with bit32
	(no `buffer.writebits` dependency, so CP0 measures the packing cost we would actually ship).

	Layout (LSB-first, 128 bits):
	  slot 7 · generation 2 · epoch 3 · age 10 · x 18 · z 18 · y 16 · yaw 8 · pitch 6 ·
	  vx 11 · vy 11 · vz 11 · state 5 · grounded 1 · hasAction 1

	CP6 ragdoll variant (spec §6.2): when `state == STATE_RAGDOLL` the 33 velocity bits carry the body's
	full rotation instead — a smallest-three quaternion (2-bit index of the dropped largest component +
	3 × 10 bits, the 33rd bit spare). Velocity reads back as zero; `rotation` is set. Still 16 B.

	@class ReplicationRecordCodec
]=]

local ReplicationRecordCodec = {}

ReplicationRecordCodec.RECORD_BYTES = 16
-- A state value no HumanoidStateType uses in the 5-bit field (slide is 30).
ReplicationRecordCodec.STATE_RAGDOLL = 29
ReplicationRecordCodec.HEADER_BYTES = 7

-- Quantisation box (spec §3): centre of the live map, ±2048 on X/Z, Y −512…+1536.
local CENTRE_X = -1228
local CENTRE_Z = -363
local POS_XZ_SCALE = 64 -- 1/64 stud
local POS_Y_SCALE = 32 -- 1/32 stud
-- The lowest Y a record can carry: lower positions clamp to it on the wire.
ReplicationRecordCodec.Y_FLOOR = -512
local Y_FLOOR = ReplicationRecordCodec.Y_FLOOR
local VEL_RANGE = 768 -- studs/s, sqrt-companded

export type Record = {
	slot: number,
	generation: number,
	epoch: number,
	ageMs: number,
	position: Vector3,
	yaw: number, -- radians
	pitch: number, -- radians, ±π/2
	velocity: Vector3,
	state: number,
	grounded: boolean,
	hasAction: boolean,
	-- CP6: full body rotation, present only on ragdoll records (it replaces velocity on the wire).
	rotation: CFrame?,
}

export type Header = {
	seq: number,
	batchTimeMs: number,
	count: number,
}

-- The bit cursor lives in module locals, not a per-call table: writeRecord/readRecord run for every body
-- every frame, and the table was a per-record allocation (A/B harness finding). Luau is single-threaded
-- and these never yield, so one shared cursor is safe.
local cb: buffer = buffer.create(0)
local cOffset = 0
local cAcc = 0
local cUsed = 0

local function clampInt(value: number, bits: number): number
	local maxValue = 2 ^ bits - 1
	if value ~= value then
		return 0 -- NaN (an owner physics glitch): encode the field's floor rather than an undefined bit pattern
	end
	return math.clamp(math.floor(value + 0.5), 0, maxValue)
end

local function put(value: number, bits: number)
	local free = 32 - cUsed
	if bits < free then
		cAcc = bit32.bor(cAcc, bit32.lshift(value, cUsed))
		cUsed += bits
	elseif bits == free then
		cAcc = bit32.bor(cAcc, bit32.lshift(value, cUsed))
		buffer.writeu32(cb, cOffset, cAcc)
		cOffset += 4
		cAcc = 0
		cUsed = 0
	else
		cAcc = bit32.bor(cAcc, bit32.lshift(bit32.extract(value, 0, free), cUsed))
		buffer.writeu32(cb, cOffset, cAcc)
		cOffset += 4
		cAcc = bit32.rshift(value, free)
		cUsed = bits - free
	end
end

local function take(bits: number): number
	local available = 32 - cUsed
	if bits <= available then
		local value = bit32.extract(cAcc, cUsed, bits)
		cUsed += bits
		if cUsed == 32 then
			cOffset += 4
			cUsed = 0
			if cOffset + 4 <= buffer.len(cb) then
				cAcc = buffer.readu32(cb, cOffset)
			end
		end
		return value
	end
	local low = bit32.extract(cAcc, cUsed, available)
	cOffset += 4
	cAcc = buffer.readu32(cb, cOffset)
	local highBits = bits - available
	local high = bit32.extract(cAcc, 0, highBits)
	cUsed = highBits
	return bit32.bor(low, bit32.lshift(high, available))
end

local function encodeVelocity(v: number): number
	local magnitude = math.min(math.abs(v), VEL_RANGE)
	local q = clampInt(1023 * math.sqrt(magnitude / VEL_RANGE), 10)
	return if v < 0 then bit32.bor(q, 1024) else q
end

local function decodeVelocity(q: number): number
	local magnitude = bit32.band(q, 1023) / 1023
	local v = magnitude * magnitude * VEL_RANGE
	return if bit32.band(q, 1024) ~= 0 then -v else v
end

-- Smallest-three quaternion: the largest |component| is dropped (recomputed from unit length), the
-- other three lie in ±1/√2 and get 10 bits each. ≈ 0.08° resolution.
local QUAT_RANGE = 1 / math.sqrt(2)

local function quaternionOf(rotation: CFrame): { number }
	local axis, angle = rotation:ToAxisAngle()
	local half = angle / 2
	local sinHalf = math.sin(half)
	return { axis.X * sinHalf, axis.Y * sinHalf, axis.Z * sinHalf, math.cos(half) }
end

local function encodeRotation(rotation: CFrame): (number, number, number, number)
	local q = quaternionOf(rotation)
	local largest = 1
	for i = 2, 4 do
		if math.abs(q[i]) > math.abs(q[largest]) then
			largest = i
		end
	end
	local sign = if q[largest] < 0 then -1 else 1 -- q and −q are the same rotation; keep the dropped one positive
	local packed: { number } = {}
	for i = 1, 4 do
		if i ~= largest then
			table.insert(packed, clampInt((q[i] * sign / QUAT_RANGE + 1) / 2 * 1023, 10))
		end
	end
	return largest - 1, packed[1], packed[2], packed[3]
end

local function decodeRotation(index: number, a: number, b: number, c: number): CFrame
	local others = { (a / 1023 * 2 - 1) * QUAT_RANGE, (b / 1023 * 2 - 1) * QUAT_RANGE, (c / 1023 * 2 - 1) * QUAT_RANGE }
	local sum = others[1] * others[1] + others[2] * others[2] + others[3] * others[3]
	local dropped = math.sqrt(math.max(0, 1 - sum))
	local q: { number } = {}
	local k = 1
	for i = 1, 4 do
		if i == index + 1 then
			q[i] = dropped
		else
			q[i] = others[k]
			k += 1
		end
	end
	-- Hostile or corrupt bits can give a non-unit quaternion: normalise (length 0 reads as identity).
	local length = math.sqrt(q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4])
	if length < 1e-6 then
		return CFrame.identity
	end
	return CFrame.new(0, 0, 0, q[1] / length, q[2] / length, q[3] / length, q[4] / length)
end

local function wrapAngle(radians: number): number
	local turns = radians / (2 * math.pi)
	return turns - math.floor(turns)
end

function ReplicationRecordCodec.writeHeader(b: buffer, offset: number, header: Header)
	buffer.writeu16(b, offset, header.seq % 65536)
	buffer.writeu32(b, offset + 2, header.batchTimeMs % 4294967296)
	buffer.writeu8(b, offset + 6, header.count)
end

function ReplicationRecordCodec.readHeader(b: buffer, offset: number): Header
	return {
		seq = buffer.readu16(b, offset),
		batchTimeMs = buffer.readu32(b, offset + 2),
		count = buffer.readu8(b, offset + 6),
	}
end

function ReplicationRecordCodec.writeRecord(b: buffer, offset: number, r: Record)
	cb, cOffset, cAcc, cUsed = b, offset, 0, 0
	put(bit32.band(r.slot, 127), 7)
	put(bit32.band(r.generation, 3), 2)
	put(bit32.band(r.epoch, 7), 3)
	put(clampInt(r.ageMs, 10), 10)
	put(clampInt((r.position.X - CENTRE_X + 2048) * POS_XZ_SCALE, 18), 18)
	put(clampInt((r.position.Z - CENTRE_Z + 2048) * POS_XZ_SCALE, 18), 18)
	put(clampInt((r.position.Y - Y_FLOOR) * POS_Y_SCALE, 16), 16)
	put(clampInt(wrapAngle(r.yaw) * 256, 9) % 256, 8)
	put(clampInt((math.clamp(r.pitch, -math.pi / 2, math.pi / 2) / math.pi + 0.5) * 63, 6), 6)
	local rotation = r.rotation
	if r.state == ReplicationRecordCodec.STATE_RAGDOLL then
		-- A ragdoll record without a rotation encodes identity, never velocity bits misread as a quaternion.
		local index, qa, qb, qc = encodeRotation(rotation or CFrame.identity)
		put(index, 2)
		put(qa, 10)
		put(qb, 10)
		put(qc, 10)
		put(0, 1) -- spare
	else
		put(encodeVelocity(r.velocity.X), 11)
		put(encodeVelocity(r.velocity.Y), 11)
		put(encodeVelocity(r.velocity.Z), 11)
	end
	put(bit32.band(r.state, 31), 5)
	put(if r.grounded then 1 else 0, 1)
	put(if r.hasAction then 1 else 0, 1)
end

function ReplicationRecordCodec.readRecord(b: buffer, offset: number): Record
	cb, cOffset, cAcc, cUsed = b, offset, buffer.readu32(b, offset), 0
	local slot = take(7)
	local generation = take(2)
	local epoch = take(3)
	local ageMs = take(10)
	local x = take(18) / POS_XZ_SCALE - 2048 + CENTRE_X
	local z = take(18) / POS_XZ_SCALE - 2048 + CENTRE_Z
	local y = take(16) / POS_Y_SCALE + Y_FLOOR
	local yaw = take(8) / 256 * 2 * math.pi
	local pitch = (take(6) / 63 - 0.5) * math.pi
	-- The variant is decided by `state`, which comes AFTER these bits: read them raw, decode below.
	local raw1 = take(11)
	local raw2 = take(11)
	local raw3 = take(11)
	local state = take(5)
	local velocity = Vector3.zero
	local rotation: CFrame? = nil
	if state == ReplicationRecordCodec.STATE_RAGDOLL then
		-- raw1..raw3 are the 33 bits as 11+11+11; re-slice into 2 + 10 + 10 + 10 + 1.
		local bits = { raw1, raw2, raw3 }
		local function slice(from: number, width: number): number
			local value = 0
			for i = 0, width - 1 do
				local bitIndex = from + i
				local word = bits[bitIndex // 11 + 1]
				value += bit32.extract(word, bitIndex % 11, 1) * 2 ^ i
			end
			return value
		end
		rotation = decodeRotation(slice(0, 2), slice(2, 10), slice(12, 10), slice(22, 10))
	else
		velocity = Vector3.new(decodeVelocity(raw1), decodeVelocity(raw2), decodeVelocity(raw3))
	end
	local grounded = take(1) == 1
	local hasAction = take(1) == 1
	return {
		slot = slot,
		generation = generation,
		epoch = epoch,
		ageMs = ageMs,
		position = Vector3.new(x, y, z),
		yaw = yaw,
		pitch = pitch,
		velocity = velocity,
		state = state,
		grounded = grounded,
		hasAction = hasAction,
		rotation = rotation,
	}
end

--[=[
	CP11 action extension (spec §6.2 `hasAction`, §6.8): 2 bytes appended after a record whose
	`hasAction` bit is set, so a batch's records are variable-length (16 or 18 B) and a reader walks
	them with `recordBytes`.

	Layout (LSB-first, 16 bits): action index 7 · variant 3 · elapsed 6.
	  - index: position in `AnimationRegistry.ids()` (sorted, shared by both realms), 0–127;
	  - variant: 0 = the entry's own asset, k = its k-th variant (the SERVER picks it, so every viewer
	    plays the same clip);
	  - elapsed: time since the grant's start at this record's sample time, in 32 ms steps, saturating
	    at 63 (≥ 2016 ms). Spec §6.2 said "normalised phase", but that needs the clip's length and the
	    registry has none (a server can't know it without loading the track); elapsed time is what a
	    receiver needs to latch the start anyway.
]=]
export type Action = {
	index: number,
	variant: number,
	elapsedMs: number,
}

ReplicationRecordCodec.ACTION_BYTES = 2
ReplicationRecordCodec.ACTION_ELAPSED_STEP_MS = 32
ReplicationRecordCodec.ACTION_ELAPSED_MAX_MS = 63 * 32

function ReplicationRecordCodec.writeAction(b: buffer, offset: number, action: Action)
	local steps = math.clamp(math.floor(action.elapsedMs / ReplicationRecordCodec.ACTION_ELAPSED_STEP_MS + 0.5), 0, 63)
	local word = bit32.bor(
		bit32.band(action.index, 127),
		bit32.lshift(bit32.band(action.variant, 7), 7),
		bit32.lshift(steps, 10)
	)
	buffer.writeu16(b, offset, word)
end

function ReplicationRecordCodec.readAction(b: buffer, offset: number): Action
	local word = buffer.readu16(b, offset)
	return {
		index = bit32.extract(word, 0, 7),
		variant = bit32.extract(word, 7, 3),
		elapsedMs = bit32.extract(word, 10, 6) * ReplicationRecordCodec.ACTION_ELAPSED_STEP_MS,
	}
end

-- Bytes this record occupies on the wire, extension included.
function ReplicationRecordCodec.recordBytes(record: Record): number
	return ReplicationRecordCodec.RECORD_BYTES + if record.hasAction then ReplicationRecordCodec.ACTION_BYTES else 0
end

--[=[
	The uplink carries the owner's timestamp as its low 10 bits in `ageMs` (Verdict: 17 B uplink). Recover the
	full value against the server's arrival time. The accepted window is [arrival − 959, arrival + 64] ms: an
	owner clock slightly ahead of the server's reads as "just now", not as a second old. A sample older than
	959 ms aliases into the future (arrival − 1000 reads as arrival + 24); ingest must detect this (R2).
]=]
ReplicationRecordCodec.OWNER_AHEAD_MS = 64

function ReplicationRecordCodec.unwrapOwnerTime(arrivalMs: number, low10: number): number
	local ahead = ReplicationRecordCodec.OWNER_AHEAD_MS
	return arrivalMs + ahead - ((arrivalMs + ahead - low10) % 1024)
end

return ReplicationRecordCodec
