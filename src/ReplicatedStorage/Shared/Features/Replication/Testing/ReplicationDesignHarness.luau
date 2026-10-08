--!strict
--[=[
	The harness adapter for the design R2 ships, wired to the REAL shared modules (codec, interpolator, render
	clock, send policy), so the acceptance spec measures exactly the production logic.

	  uplink    u8 packet id + one 16 B record, unreliable; the record's `ageMs` carries the owner's timestamp
	            (low 10 bits). With `uplinkOnChange`, the owner runs `ReplicationSendRules` too.
	  server    unwraps the owner time, keeps the newest sample, relays by `ReplicationSendRules`.
	  downlink  u8 id + 7 B header + one 16 B record, unreliable, sequence-numbered.
	  viewer    `ReplicationSampleTracker` on the owner's timeline, `ReplicationRenderClockSystem` delay, dead reckoning when the
	            buffer runs out.

	@class ReplicationDesignHarness
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationShared = ReplicatedStorage.Shared.Features.Replication
local Codec = require(ReplicationShared.Net.ReplicationRecordCodec)
local Interp = require(ReplicationShared.State.ReplicationSampleTracker)
local ReplicationRenderClockSystem = require(ReplicationShared.Systems.ReplicationRenderClockSystem)
local ReplicationSendRules = require(ReplicationShared.Rules.ReplicationSendRules)
local ReplicationRunHarness = require(ReplicationShared.Testing.ReplicationRunHarness)

local ReplicationDesignHarness = {}

local PACKET_ID = 2
local MAX_RECKON_MS = 60

export type Options = {
	groundBelow: ((position: Vector3) -> number)?,
	uplinkOnChange: boolean?,
}

export type Probe = {
	delayLog: { { atMs: number, delayMs: number } },
}

type Latest = { record: Codec.Record, sampleMs: number, fresh: boolean }

function ReplicationDesignHarness.new(options: Options?): (ReplicationRunHarness.System, Probe)
	local opts: Options = options or {}
	local groundBelow = opts.groundBelow
	local uplinkOnChange = opts.uplinkOnChange == true
	local probe: Probe = { delayLog = {} }

	-- owner
	local epoch = 0
	local ownerPolicy = ReplicationSendRules.new()
	local ownerLastSent: Codec.Record? = nil

	-- server
	local latest: Latest? = nil
	local lastSeenSampleMs = -math.huge
	local serverPolicy = ReplicationSendRules.new()
	local serverLastSent: Codec.Record? = nil
	local batchSeq = 0

	-- viewer
	local samples = Interp.newBuffer()
	local clock = ReplicationRenderClockSystem.new()
	local starving = false

	local system: ReplicationRunHarness.System = {
		name = "Venture (R1 modules)",

		ownerFrame = function(nowMs, truth, respawned)
			if respawned then
				epoch = (epoch + 1) % 8
			end
			local record: Codec.Record = {
				slot = 0,
				generation = 0,
				epoch = epoch,
				ageMs = math.floor(nowMs) % 1024,
				position = truth.position,
				yaw = truth.yaw,
				pitch = 0,
				velocity = truth.velocity,
				state = truth.state,
				grounded = truth.grounded,
				hasAction = false,
				rotation = nil,
			}
			if uplinkOnChange then
				local decision =
					ReplicationSendRules.decide(ownerPolicy, nowMs, ReplicationSendRules.changed(ownerLastSent, record))
				if decision == nil then
					return {}
				end
				ownerLastSent = record
			end
			local packet = buffer.create(1 + Codec.RECORD_BYTES)
			buffer.writeu8(packet, 0, PACKET_ID)
			Codec.writeRecord(packet, 1, record)
			return { { payload = packet, reliable = false } }
		end,

		serverReceive = function(nowMs, payload)
			local record = Codec.readRecord(payload, 1)
			local sampleMs = Codec.unwrapOwnerTime(math.floor(nowMs), record.ageMs)
			if sampleMs > lastSeenSampleMs then
				lastSeenSampleMs = sampleMs
				latest = { record = record, sampleMs = sampleMs, fresh = true }
			end
		end,

		serverFrame = function(nowMs, _distance)
			local current = latest
			if current == nil then
				return {}
			end
			local changed = current.fresh and ReplicationSendRules.changed(serverLastSent, current.record)
			current.fresh = false
			if ReplicationSendRules.decide(serverPolicy, nowMs, changed) == nil then
				return {}
			end
			serverLastSent = current.record
			batchSeq = (batchSeq + 1) % 65536
			local batch = buffer.create(1 + Codec.HEADER_BYTES + Codec.RECORD_BYTES)
			buffer.writeu8(batch, 0, PACKET_ID)
			Codec.writeHeader(batch, 1, { seq = batchSeq, batchTimeMs = math.floor(nowMs), count = 1 })
			local r = current.record
			Codec.writeRecord(batch, 1 + Codec.HEADER_BYTES, {
				slot = 1,
				generation = 0,
				epoch = r.epoch,
				ageMs = math.clamp(math.floor(nowMs) - current.sampleMs, 0, 1023),
				position = r.position,
				yaw = r.yaw,
				pitch = r.pitch,
				velocity = r.velocity,
				state = r.state,
				grounded = r.grounded,
				hasAction = false,
				rotation = nil,
			})
			return { { payload = batch, reliable = false } }
		end,

		viewerReceive = function(nowMs, payload)
			local header = Codec.readHeader(payload, 1)
			local record = Codec.readRecord(payload, 1 + Codec.HEADER_BYTES)
			local sampleTime = header.batchTimeMs - record.ageMs
			local result: Interp.PushResult = Interp.push(samples, record.epoch, {
				timeMs = sampleTime,
				position = record.position,
				velocity = record.velocity,
				yaw = record.yaw,
				state = record.state,
				grounded = record.grounded,
				rotation = nil,
			})
			ReplicationRenderClockSystem.onBatch(
				clock,
				nowMs,
				header.seq,
				nowMs - sampleTime,
				Interp.isNewSample(result)
			)
		end,

		viewerRender = function(nowMs)
			ReplicationRenderClockSystem.noteFrame(clock, nowMs)
			local delay = ReplicationRenderClockSystem.advance(clock, nowMs, starving, Interp.reachMs(samples, nowMs))
			table.insert(probe.delayLog, { atMs = nowMs, delayMs = delay })
			local renderTime = nowMs - delay
			local e = Interp.evaluate(samples, renderTime)
			if e.mode == "empty" then
				return nil
			end
			starving = Interp.isStarving(e.mode)
			if e.mode == "extrapolate" or e.mode == "hold" then
				return Interp.reckon(samples, renderTime, MAX_RECKON_MS, groundBelow)
			end
			return e.position
		end,
	}
	return system, probe
end

return ReplicationDesignHarness
