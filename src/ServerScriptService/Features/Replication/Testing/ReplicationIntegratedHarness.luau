--!strict
--[=[
	ReplicationIntegratedHarness: the R1 harness adapter rebuilt on the modules R2 ships (Verdict: "Measure the
	integrated build"; plan R2 Task 13), so the acceptance numbers describe the real pipeline:

	  owner   ReplicationUplinkSender — send on change, two resends, 1 Hz repair; the current sample plus two previous,
	          aged from a u32 send time (ReplicationUplinkCodec)
	  server  ReplicationUplinkCodec.decode → ReplicationUplinkRules → ReplicationFanoutSystem (send policy, visibility, encode
	          once, 700 B cap and budget). The RequestHandler limiter is measured separately (ReplicationLoadHarness)
	  viewer  ReplicationRemoteBodyTracker — slot table, enter, validated batches, render clock, interpolation, dead reckoning

	One subject (the trace) and one viewer standing `viewerDistance` studs beside it. A respawn in the trace
	bumps the epoch on the owner and the server at once and sends the viewer a reliable slot entry, as the
	real server does. Server → viewer payloads carry a one-byte tag (harness framing only): 1 slot entry,
	2 enter, 3 batch.

	@class ReplicationIntegratedHarness
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicationShared = ReplicatedStorage.Shared.Features.Replication
local ReplicationRecordCodec = require(ReplicationShared.Net.ReplicationRecordCodec)
local ReplicationUplinkCodec = require(ReplicationShared.Net.ReplicationUplinkCodec)
local ReplicationRunHarness = require(ReplicationShared.Testing.ReplicationRunHarness)
local ReplicationUplinkSender = require(ReplicatedStorage.Client.Features.Replication.Net.ReplicationUplinkSender)
local ReplicationRemoteBodyTracker =
	require(ReplicatedStorage.Client.Features.Replication.State.ReplicationRemoteBodyTracker)
local ReplicationUplinkRules = require(ServerScriptService.Features.Replication.Rules.ReplicationUplinkRules)
local ReplicationFanoutSystem = require(ServerScriptService.Features.Replication.Systems.ReplicationFanoutSystem)

local ReplicationIntegratedHarness = {}

local SUBJECT_SLOT, VIEWER_SLOT = 1, 2
local SUBJECT_USER, VIEWER_USER = 1, 2
local TAG_SLOT, TAG_ENTER, TAG_BATCH = 1, 2, 3
local ENTER_HEADER_BYTES = 6 -- harness framing of enterPayload: slot u8 · generation u8 · batchTimeMs u32
local ACTION_COUNT = 128 -- R2 never relays actions; any index is "in the registry" here

export type Options = {
	groundBelow: ((position: Vector3) -> number)?,
}

export type Probe = {
	delayLog: { { atMs: number, delayMs: number } },
}

local function tagged(tag: number, body: buffer): buffer
	local out = buffer.create(1 + buffer.len(body))
	buffer.writeu8(out, 0, tag)
	buffer.copy(out, 1, body)
	return out
end

local function untag(payload: buffer): (number, buffer)
	local body = buffer.create(buffer.len(payload) - 1)
	buffer.copy(body, 0, payload, 1)
	return buffer.readu8(payload, 0), body
end

function ReplicationIntegratedHarness.new(options: Options?): (ReplicationRunHarness.System, Probe)
	local groundBelow = if options ~= nil then options.groundBelow else nil
	local probe: Probe = { delayLog = {} }
	local epoch = 1

	-- owner
	local sender = ReplicationUplinkSender.new()

	-- server: the subject (alive from its first accepted sample) and a ready viewer
	local world = ReplicationFanoutSystem.newWorld()
	local subject = ReplicationFanoutSystem.newBody(SUBJECT_USER, SUBJECT_SLOT, 0, Vector3.zero)
	local viewer = ReplicationFanoutSystem.newBody(VIEWER_USER, VIEWER_SLOT, 0, Vector3.zero)
	for _, body in { subject, viewer } do
		body.epoch.value = epoch
		body.ready = true
		ReplicationFanoutSystem.respawned(body)
		ReplicationFanoutSystem.addBody(world, body)
	end
	subject.alive = false
	local frameNowMs = 0
	local slotEntryPending = false
	local outgoing: { ReplicationRunHarness.Outgoing } = {}
	local hooks: ReplicationFanoutSystem.Hooks = {
		send = function(_viewer, batch)
			table.insert(outgoing, { payload = tagged(TAG_BATCH, batch), reliable = false })
		end,
		visibility = function(_viewer, body, entered)
			if not entered then
				return
			end
			local payload = ReplicationFanoutSystem.enterPayload(body, frameNowMs)
			local enter = buffer.create(ENTER_HEADER_BYTES + ReplicationRecordCodec.RECORD_BYTES)
			buffer.writeu8(enter, 0, payload.slot)
			buffer.writeu8(enter, 1, payload.generation)
			buffer.writeu32(enter, 2, payload.batchTimeMs)
			buffer.copy(enter, ENTER_HEADER_BYTES, payload.record)
			table.insert(outgoing, { payload = tagged(TAG_ENTER, enter), reliable = true })
		end,
	}

	-- viewer
	local remote = ReplicationRemoteBodyTracker.new(VIEWER_USER)
	ReplicationRemoteBodyTracker.applySlot(
		remote,
		{ slot = SUBJECT_SLOT, userId = SUBJECT_USER, generation = 0, epoch = epoch, active = true }
	)
	local slots: { number } = {}
	local cframes: { CFrame } = {}

	local system: ReplicationRunHarness.System = {
		name = "Venture (R2 integrated)",

		ownerFrame = function(nowMs, truth, respawned)
			if respawned then
				epoch = (epoch + 1) % 256
				ReplicationUplinkSender.reset(sender)
				subject.epoch.value = epoch
				ReplicationFanoutSystem.respawned(subject)
				subject.position = truth.position
				slotEntryPending = true
			end
			local record: ReplicationRecordCodec.Record = {
				slot = 0,
				generation = 0,
				epoch = epoch,
				ageMs = 0,
				position = truth.position,
				yaw = truth.yaw,
				pitch = 0,
				velocity = truth.velocity,
				state = truth.state,
				grounded = truth.grounded,
				hasAction = false,
				rotation = nil,
			}
			local packet = ReplicationUplinkSender.step(sender, math.floor(nowMs), record)
			if packet == nil then
				return {}
			end
			return { { payload = packet, reliable = false } }
		end,

		serverReceive = function(nowMs, payload)
			local ok, _reason, uplink = ReplicationUplinkCodec.decode(payload)
			if not ok or uplink == nil then
				return
			end
			if ReplicationUplinkRules.ingest(subject.ingest, payload, uplink, math.floor(nowMs)) > 0 then
				local latest = subject.ingest.latest
				if latest ~= nil then
					subject.position = latest.position
					subject.alive = true
				end
			end
		end,

		serverFrame = function(nowMs, viewerDistance)
			frameNowMs = math.floor(nowMs)
			outgoing = {}
			viewer.position = subject.position + Vector3.new(viewerDistance, 0, 0)
			if slotEntryPending then
				slotEntryPending = false
				local entry = buffer.create(1)
				buffer.writeu8(entry, 0, epoch)
				table.insert(outgoing, { payload = tagged(TAG_SLOT, entry), reliable = true })
			end
			ReplicationFanoutSystem.step(world, frameNowMs, hooks)
			return outgoing
		end,

		viewerReceive = function(nowMs, payload)
			local tag, body = untag(payload)
			if tag == TAG_SLOT then
				ReplicationRemoteBodyTracker.applySlot(remote, {
					slot = SUBJECT_SLOT,
					userId = SUBJECT_USER,
					generation = 0,
					epoch = buffer.readu8(body, 0),
					active = true,
				})
			elseif tag == TAG_ENTER then
				local record = buffer.create(ReplicationRecordCodec.RECORD_BYTES)
				buffer.copy(record, 0, body, ENTER_HEADER_BYTES, ReplicationRecordCodec.RECORD_BYTES)
				ReplicationRemoteBodyTracker.enter(
					remote,
					buffer.readu8(body, 0),
					buffer.readu8(body, 1),
					buffer.readu32(body, 2),
					record
				)
			elseif tag == TAG_BATCH then
				ReplicationRemoteBodyTracker.onBatch(remote, body, nowMs, ACTION_COUNT)
			end
		end,

		viewerRender = function(nowMs)
			local count = ReplicationRemoteBodyTracker.frame(remote, nowMs, slots, cframes, groundBelow)
			table.insert(probe.delayLog, { atMs = nowMs, delayMs = remote.delayMs })
			for i = 1, count do
				if slots[i] == SUBJECT_SLOT then
					return cframes[i].Position
				end
			end
			return nil
		end,
	}
	return system, probe
end

return ReplicationIntegratedHarness
