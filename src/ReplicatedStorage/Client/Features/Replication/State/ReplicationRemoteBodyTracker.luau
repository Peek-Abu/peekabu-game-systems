--!strict
--[=[
	ReplicationRemoteBodyTracker: everything a viewer knows about other players' bodies (spec §6.4–§6.7; plan R2 Task 11).

	- The reliable SLOT TABLE (`applySlot`) says which player each slot is, in which generation and epoch.
	  A new generation replaces the body outright (a rejoiner inherits nothing). A newer epoch the buffer
	  never saw — its bump records were lost — resets the buffer to it (R1 review: the interpolator drops
	  any epoch other than current + 1, so only the reliable table can recover a lost bump).
	- `enter` / `leave` follow the server's visibility set; both start the buffer fresh, so a body that comes
	  back never slides from where it was last seen (spike CP10).
	- `onBatch` validates a downlink batch before decoding (ReplicationBatchCodec), pushes each record into its
	  body, and gives the render clock ONE lateness vote: the largest among the batch's NEW samples
	  (`ReplicationSampleTracker.isNewSample` of what `push` did) — resends, repairs of held samples and
	  stragglers never vote.
	- `frame` advances the render clock (starving = some body was in `hold`; `behind` never counts), then
	  evaluates every visible body on the allocation-free path, dead-reckoning (gravity, ground) when it runs
	  past its newest sample. Each placed body also gets its movement state at the same render time
	  (`motionState`, `motionGrounded`, `motionVelocity`), which puppet locomotion reads (R3).

	Pure: time is passed in (session ms); the caller supplies the ground query.

	@class ReplicationRemoteBodyTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicationShared = ReplicatedStorage.Shared.Features.Replication
local ReplicationRecordCodec = require(ReplicationShared.Net.ReplicationRecordCodec)
local ReplicationBatchCodec = require(ReplicationShared.Net.ReplicationBatchCodec)
local ReplicationSampleTracker = require(ReplicationShared.State.ReplicationSampleTracker)
local ReplicationRenderClockSystem = require(ReplicationShared.Systems.ReplicationRenderClockSystem)

local ReplicationRemoteBodyTracker = {}

local MAX_RECKON_MS = 60
ReplicationRemoteBodyTracker.MAX_RECKON_MS = MAX_RECKON_MS

export type SlotEntry = {
	slot: number,
	userId: number,
	generation: number,
	epoch: number,
	active: boolean,
}

export type SlotChange = "added" | "replaced" | "released" | "epoch"

export type Body = {
	slot: number,
	userId: number,
	generation: number, -- low 2 bits, as on the wire
	epoch: number, -- full 8-bit epoch from the slot table
	samples: ReplicationSampleTracker.Buffer,
	hint: ReplicationSampleTracker.Hint,
	visible: boolean,
	-- The nearest sample's state at the last rendered frame (puppet locomotion, R3).
	motionState: number,
	motionGrounded: boolean,
	motionVelocity: Vector3,
}

export type Stats = {
	batches: number,
	rejected: number,
	records: number,
	dropped: number,
	flushed: number,
	resets: number,
	newSamples: number,
	interpolate: number,
	extrapolate: number,
	hold: number,
	behind: number,
	-- Why each reliable Enter / Leave was applied or ignored (an ignored Enter leaves no other trace).
	enterAccepted: number,
	enterNoBody: number,
	enterGeneration: number,
	enterBadRecord: number,
	enterSampleDropped: number,
	leaveAccepted: number,
	leaveIgnored: number,
}

export type State = {
	localUserId: number,
	bodies: { [number]: Body }, -- by slot
	clock: ReplicationRenderClockSystem.Clock,
	starving: boolean,
	delayMs: number,
	stats: Stats,
}

function ReplicationRemoteBodyTracker.new(localUserId: number): State
	local clock = ReplicationRenderClockSystem.new()
	return {
		localUserId = localUserId,
		bodies = {},
		clock = clock,
		starving = false,
		delayMs = clock.delayMs,
		stats = {
			batches = 0,
			rejected = 0,
			records = 0,
			dropped = 0,
			flushed = 0,
			resets = 0,
			newSamples = 0,
			interpolate = 0,
			extrapolate = 0,
			hold = 0,
			behind = 0,
			enterAccepted = 0,
			enterNoBody = 0,
			enterGeneration = 0,
			enterBadRecord = 0,
			enterSampleDropped = 0,
			leaveAccepted = 0,
			leaveIgnored = 0,
		},
	}
end

local function newBody(entry: SlotEntry): Body
	local samples = ReplicationSampleTracker.newBuffer()
	ReplicationSampleTracker.resetEpoch(samples, entry.epoch)
	return {
		slot = entry.slot,
		userId = entry.userId,
		generation = entry.generation % 4,
		epoch = entry.epoch,
		samples = samples,
		hint = ReplicationSampleTracker.newHint(),
		visible = false,
		motionState = 0,
		motionGrounded = true,
		motionVelocity = Vector3.zero,
	}
end

local function sampleOf(record: ReplicationRecordCodec.Record, timeMs: number): ReplicationSampleTracker.Sample
	return {
		timeMs = timeMs,
		position = record.position,
		velocity = record.velocity,
		yaw = record.yaw,
		state = record.state,
		grounded = record.grounded,
		rotation = record.rotation,
	}
end

--[=[
	Apply one slot-table row. Returns what changed; for "replaced" and "released" the body returned is the
	one that went away (the caller hides its puppet), otherwise the current body.
]=]
function ReplicationRemoteBodyTracker.applySlot(state: State, entry: SlotEntry): (SlotChange?, Body?)
	local existing = state.bodies[entry.slot]
	local generation = entry.generation % 4
	if not entry.active then
		if existing ~= nil and existing.generation == generation then
			state.bodies[entry.slot] = nil
			return "released", existing
		end
		return nil, nil
	end
	if entry.userId == state.localUserId then
		return nil, nil -- this client's own body is the owner rig, never a remote body
	end
	if existing == nil then
		state.bodies[entry.slot] = newBody(entry)
		return "added", nil
	end
	if existing.generation ~= generation or existing.userId ~= entry.userId then
		state.bodies[entry.slot] = newBody(entry)
		return "replaced", existing
	end
	if entry.epoch ~= existing.epoch then
		existing.epoch = entry.epoch
		if existing.samples.epoch ~= entry.epoch % 8 then
			ReplicationSampleTracker.resetEpoch(existing.samples, entry.epoch)
			state.stats.resets += 1
		end
		return "epoch", existing
	end
	return nil, existing
end

function ReplicationRemoteBodyTracker.enter(
	state: State,
	slot: number,
	generation: number,
	batchTimeMs: number,
	recordBytes: buffer
): Body?
	local body = state.bodies[slot]
	local stats = state.stats
	if body == nil then
		stats.enterNoBody += 1
		return nil
	elseif body.generation ~= generation % 4 then
		stats.enterGeneration += 1
		return nil
	elseif buffer.len(recordBytes) ~= ReplicationRecordCodec.RECORD_BYTES then
		stats.enterBadRecord += 1
		return nil
	end
	local record = ReplicationRecordCodec.readRecord(recordBytes, 0)
	body.visible = true
	stats.enterAccepted += 1
	ReplicationSampleTracker.resetEpoch(body.samples, body.epoch)
	local pushed =
		ReplicationSampleTracker.push(body.samples, record.epoch, sampleOf(record, batchTimeMs - record.ageMs))
	if pushed == "dropped" then
		stats.enterSampleDropped += 1
	end
	return body
end

function ReplicationRemoteBodyTracker.leave(state: State, slot: number, generation: number): Body?
	local body = state.bodies[slot]
	if body == nil or body.generation ~= generation % 4 then
		state.stats.leaveIgnored += 1
		return nil
	end
	state.stats.leaveAccepted += 1
	body.visible = false
	ReplicationSampleTracker.resetEpoch(body.samples, body.epoch)
	return body
end

function ReplicationRemoteBodyTracker.onBatch(
	state: State,
	batch: buffer,
	arrivalMs: number,
	actionCount: number
): boolean
	local stats = state.stats
	if not ReplicationBatchCodec.validate(batch, actionCount) then
		stats.rejected += 1
		return false
	end
	stats.batches += 1
	local header = ReplicationRecordCodec.readHeader(batch, 0)
	local offset = ReplicationRecordCodec.HEADER_BYTES
	local anyNew = false
	local worstLateness = 0
	for _ = 1, header.count do
		local record = ReplicationRecordCodec.readRecord(batch, offset)
		offset += ReplicationRecordCodec.recordBytes(record)
		stats.records += 1
		local body = state.bodies[record.slot]
		if body == nil or not body.visible or body.generation ~= record.generation then
			stats.dropped += 1
			continue
		end
		local sampleMs = header.batchTimeMs - record.ageMs
		-- Annotated: Luau widens a singleton-union return to `string` on an unannotated local.
		local result: ReplicationSampleTracker.PushResult =
			ReplicationSampleTracker.push(body.samples, record.epoch, sampleOf(record, sampleMs))
		if result == "dropped" then
			stats.dropped += 1
		elseif result == "flushed" then
			stats.flushed += 1
		end
		if ReplicationSampleTracker.isNewSample(result) then
			anyNew = true
			stats.newSamples += 1
			worstLateness = math.max(worstLateness, arrivalMs - sampleMs)
		end
	end
	ReplicationRenderClockSystem.onBatch(state.clock, arrivalMs, header.seq, worstLateness, anyNew)
	return true
end

--[=[
	One rendered frame: fills `outSlots[i]` / `outCFrames[i]` for each visible body with samples and returns
	the count. `groundBelow(position)` returns the standing root height under a position (or -math.huge).
]=]
function ReplicationRemoteBodyTracker.frame(
	state: State,
	nowMs: number,
	outSlots: { number },
	outCFrames: { CFrame },
	groundBelow: ((position: Vector3) -> number)?
): number
	local clock = state.clock
	ReplicationRenderClockSystem.noteFrame(clock, nowMs)
	local reach = math.huge
	for _, body in state.bodies do
		if body.visible then
			reach = math.min(reach, ReplicationSampleTracker.reachMs(body.samples, nowMs))
		end
	end
	local delay = ReplicationRenderClockSystem.advance(clock, nowMs, state.starving, reach)
	state.delayMs = delay
	local renderTime = nowMs - delay
	local stats = state.stats
	local starving = false
	local count = 0
	table.clear(outSlots)
	table.clear(outCFrames)
	for slot, body in state.bodies do
		if not body.visible then
			continue
		end
		local position: Vector3, yaw: number, mode: ReplicationSampleTracker.Mode =
			ReplicationSampleTracker.evaluatePose(body.samples, renderTime, body.hint)
		if mode == "empty" then
			continue
		end
		if ReplicationSampleTracker.isStarving(mode) then
			starving = true
		end
		if mode == "interpolate" then
			stats.interpolate += 1
		elseif mode == "extrapolate" then
			stats.extrapolate += 1
		elseif mode == "hold" then
			stats.hold += 1
		else
			stats.behind += 1
		end
		if mode == "extrapolate" or mode == "hold" then
			local reckoned = ReplicationSampleTracker.reckon(body.samples, renderTime, MAX_RECKON_MS, groundBelow)
			if reckoned ~= nil then
				position = reckoned
			end
		end
		body.motionState, body.motionGrounded, body.motionVelocity =
			ReplicationSampleTracker.motionAt(body.samples, renderTime, body.hint)
		count += 1
		outSlots[count] = slot
		outCFrames[count] = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	end
	state.starving = starving
	return count
end

function ReplicationRemoteBodyTracker.counts(state: State): (number, number)
	local known, visible = 0, 0
	for _, body in state.bodies do
		known += 1
		if body.visible then
			visible += 1
		end
	end
	return known, visible
end

--[=[
	One line per known body for the F4 debugger, keyed by slot: who it is, the slot-table generation and epoch
	against the epoch its buffer accepts, whether it is in range, and how many samples it holds.
]=]
function ReplicationRemoteBodyTracker.describe(state: State): { [string]: string }
	local rows: { [string]: string } = {}
	for slot, body in state.bodies do
		rows[tostring(slot)] = string.format(
			"user %d · gen %d · epoch %d (buffer %d) · %s · %d samples",
			body.userId,
			body.generation,
			body.epoch,
			body.samples.epoch,
			if body.visible then "visible" else "hidden",
			#body.samples.samples
		)
	end
	return rows
end

return ReplicationRemoteBodyTracker
