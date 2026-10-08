--!strict
--[=[
	ReplicationFanoutSystem: one server frame of the downlink (spec §6.4, §6.5; plan R2 Task 7).

	1. Every live body's send policy decides ONCE whether its newest accepted sample goes out this frame
	   (change / resend / repair — the v3 policy the Verdict chose).
	2. For every ready, live viewer: distance visibility is updated against every other live body (600 /
	   630 studs; `hooks.visibility` reports enter and leave — the shell sends the reliable full-state
	   record and updates the public-data relevant set), and the bodies it has loaded that are due —
	   scheduled by their policy, or pending from a frame where they were not sent — are handed to
	   `ReplicationDownlinkSystem.pack` with their distances: its priority accumulator and far cap pick what fits
	   under the 700 B cap and the 24 KB/s budget.
	3. Encode once: a due body is encoded at most once per frame with the frame time as batch time, so every
	   viewer receives the same bytes for it.

	A viewer never receives its own body. Pure: no Instances, no services; time is server session ms.

	@class ReplicationFanoutSystem
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicationServer = ServerScriptService.Features.Replication
local ReplicationRecordCodec = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationRecordCodec)
local ReplicationSendRules = require(ReplicatedStorage.Shared.Features.Replication.Rules.ReplicationSendRules)
local ReplicationUplinkRules = require(ReplicationServer.Rules.ReplicationUplinkRules)
local ReplicationSlotTracker = require(ReplicationServer.State.ReplicationSlotTracker)
local ReplicationVisibilityTracker = require(ReplicationServer.State.ReplicationVisibilityTracker)
local ReplicationDownlinkSystem = require(ReplicationServer.Systems.ReplicationDownlinkSystem)

local ReplicationFanoutSystem = {}

local DEFAULT_MAX_HEALTH = 100
ReplicationFanoutSystem.DEFAULT_MAX_HEALTH = DEFAULT_MAX_HEALTH

export type Body = {
	userId: number,
	slot: number,
	generation: number,
	epoch: ReplicationSlotTracker.Epoch,
	ready: boolean, -- the client finished the handshake and can receive
	alive: boolean, -- has a spawned body
	position: Vector3, -- newest accepted position, or the spawn point
	ingest: ReplicationUplinkRules.State,
	policy: ReplicationSendRules.Policy,
	lastSent: ReplicationRecordCodec.Record?,
	scheduled: boolean, -- the send policy picked this body this frame
	frameBytes: buffer, -- this body's encoding, reused every frame
	visibility: ReplicationVisibilityTracker.Set, -- as a viewer: the bodies it has loaded
	viewer: ReplicationDownlinkSystem.Viewer,
	relevant: { [number]: boolean }, -- userIds whose public data this viewer may see (loaded + self)
	health: number,
	maxHealth: number,
}

export type World = {
	bodies: { [number]: Body }, -- by slot
	candidates: { number }, -- scratch, reused per viewer
	distances: { number }, -- scratch, parallel to `candidates`: studs from the viewer
	bytes: { [number]: buffer }, -- slot → that body's frameBytes
	lengths: { [number]: number }, -- slot → bytes encoded this frame (0 = not yet)
}

export type Hooks = {
	send: (viewer: Body, batch: buffer) -> (),
	visibility: (viewer: Body, subject: Body, entered: boolean) -> (),
}

function ReplicationFanoutSystem.newWorld(): World
	return { bodies = {}, candidates = {}, distances = {}, bytes = {}, lengths = {} }
end

function ReplicationFanoutSystem.newBody(userId: number, slot: number, generation: number, position: Vector3): Body
	return {
		userId = userId,
		slot = slot,
		generation = generation,
		epoch = ReplicationSlotTracker.newEpoch(),
		ready = false,
		alive = false,
		position = position,
		ingest = ReplicationUplinkRules.new(),
		policy = ReplicationSendRules.new(),
		lastSent = nil,
		scheduled = false,
		frameBytes = buffer.create(ReplicationDownlinkSystem.SCRATCH_BYTES),
		visibility = ReplicationVisibilityTracker.new(),
		viewer = ReplicationDownlinkSystem.newViewer(),
		relevant = { [userId] = true },
		health = DEFAULT_MAX_HEALTH,
		maxHealth = DEFAULT_MAX_HEALTH,
	}
end

function ReplicationFanoutSystem.addBody(world: World, body: Body)
	world.bodies[body.slot] = body
	world.bytes[body.slot] = body.frameBytes
	world.lengths[body.slot] = 0
end

--[=[
	Remove a body (its player left). Every viewer that had it loaded gets a leave first.
]=]
function ReplicationFanoutSystem.removeBody(world: World, slot: number, hooks: Hooks): Body?
	local subject = world.bodies[slot]
	if subject == nil then
		return nil
	end
	for _, viewer in world.bodies do
		if viewer ~= subject and ReplicationVisibilityTracker.remove(viewer.visibility, slot) then
			ReplicationDownlinkSystem.forget(viewer.viewer, slot)
			hooks.visibility(viewer, subject, false)
		end
	end
	world.bodies[slot] = nil
	world.bytes[slot] = nil
	world.lengths[slot] = nil
	return subject
end

--[=[
	A new body after a successful epoch bump: alive, full health, a fresh send policy, and ingest reset to
	the new epoch (samples from the previous body are dropped from here on).
]=]
function ReplicationFanoutSystem.respawned(body: Body)
	body.alive = true
	body.health = body.maxHealth
	body.policy = ReplicationSendRules.new()
	body.lastSent = nil
	body.scheduled = false
	ReplicationUplinkRules.reset(body.ingest, body.epoch.value)
end

-- A viewer starting the stream again (a repeated handshake): nothing loaded, nothing owed.
function ReplicationFanoutSystem.resetViewer(body: Body)
	body.visibility = ReplicationVisibilityTracker.new()
	body.viewer = ReplicationDownlinkSystem.newViewer()
	body.relevant = { [body.userId] = true }
end

--[=[
	Apply a new maximum health. Current health is clamped DOWN to it, never healed up. Refuses NaN,
	non-positive and infinite values (returns false, nothing changes).
]=]
function ReplicationFanoutSystem.setMaxHealth(body: Body, maxHealth: number): boolean
	if maxHealth ~= maxHealth or maxHealth <= 0 or maxHealth == math.huge then
		return false
	end
	local wasFull = body.health >= body.maxHealth
	body.maxHealth = maxHealth
	if wasFull or body.health > maxHealth then
		body.health = maxHealth
	end
	return true
end

--[=[
	The full-state record a viewer gets when `subject` enters its set (spec §6.4 "entering relevance"): the
	newest accepted sample, or — before the first uplink of a fresh body — a still record at the spawn point.
]=]
function ReplicationFanoutSystem.enterRecord(subject: Body, nowMs: number): (ReplicationRecordCodec.Record, number)
	local latest = subject.ingest.latest
	if latest ~= nil then
		return latest, subject.ingest.latestMs
	end
	return {
		slot = subject.slot,
		generation = subject.generation,
		epoch = subject.epoch.value,
		ageMs = 0,
		position = subject.position,
		yaw = 0,
		pitch = 0,
		velocity = Vector3.zero,
		state = Enum.HumanoidStateType.Running.Value,
		grounded = true,
		hasAction = false,
		rotation = nil,
	},
		nowMs
end

export type EnterPayload = {
	slot: number,
	generation: number,
	batchTimeMs: number,
	record: buffer,
}

--[=[
	The `Enter` packet payload for `subject` entering a viewer's set: `enterRecord` encoded as one 16 B
	record (age relative to `nowMs`, the batch time the viewer anchors it to). The single place that packs
	it: the server shell sends it and the replication harness feeds the same bytes to its client model.
]=]
function ReplicationFanoutSystem.enterPayload(subject: Body, nowMs: number): EnterPayload
	local record, sampleMs = ReplicationFanoutSystem.enterRecord(subject, nowMs)
	local bytes = buffer.create(ReplicationRecordCodec.RECORD_BYTES)
	ReplicationDownlinkSystem.encode(
		bytes,
		subject.slot,
		subject.generation,
		subject.epoch.value,
		record,
		sampleMs,
		nowMs
	)
	return { slot = subject.slot, generation = subject.generation, batchTimeMs = nowMs, record = bytes }
end

local function ensureEncoded(world: World, subject: Body, nowMs: number)
	local latest = subject.ingest.latest
	if latest ~= nil and world.lengths[subject.slot] == 0 then
		world.lengths[subject.slot] = ReplicationDownlinkSystem.encode(
			subject.frameBytes,
			subject.slot,
			subject.generation,
			subject.epoch.value,
			latest,
			subject.ingest.latestMs,
			nowMs
		)
	end
end

--[=[
	Run one frame. Returns how many batches were handed to `hooks.send`.
]=]
function ReplicationFanoutSystem.step(world: World, nowMs: number, hooks: Hooks): number
	local bodies = world.bodies
	local lengths = world.lengths

	for slot, subject in bodies do
		lengths[slot] = 0
		subject.scheduled = false
		local latest = subject.ingest.latest
		if subject.alive and latest ~= nil then
			local changed = subject.ingest.fresh and ReplicationSendRules.changed(subject.lastSent, latest)
			subject.ingest.fresh = false
			if ReplicationSendRules.decide(subject.policy, nowMs, changed) ~= nil then
				subject.scheduled = true
				subject.lastSent = latest
			end
		end
	end

	local sent = 0
	local candidates = world.candidates
	local distances = world.distances
	for _, viewer in bodies do
		if not (viewer.ready and viewer.alive) then
			continue
		end
		table.clear(candidates)
		table.clear(distances)
		local pending = viewer.viewer.pending
		for slot, subject in bodies do
			if subject == viewer then
				continue
			end
			local change: ReplicationVisibilityTracker.Change? = nil
			if subject.alive then
				change = ReplicationVisibilityTracker.update(viewer.visibility, viewer.position, slot, subject.position)
			elseif ReplicationVisibilityTracker.remove(viewer.visibility, slot) then
				change = "left"
			end
			if change == "entered" then
				hooks.visibility(viewer, subject, true)
			elseif change == "left" then
				ReplicationDownlinkSystem.forget(viewer.viewer, slot)
				hooks.visibility(viewer, subject, false)
			end
			if
				ReplicationVisibilityTracker.has(viewer.visibility, slot)
				and subject.ingest.latest ~= nil
				and (subject.scheduled or pending[slot] == true)
			then
				ensureEncoded(world, subject, nowMs)
				table.insert(candidates, slot)
				table.insert(distances, (subject.position - viewer.position).Magnitude)
			end
		end
		local batch = ReplicationDownlinkSystem.pack(viewer.viewer, nowMs, candidates, world.bytes, lengths, distances)
		if batch ~= nil then
			hooks.send(viewer, batch)
			sent += 1
		end
	end
	return sent
end

return ReplicationFanoutSystem
