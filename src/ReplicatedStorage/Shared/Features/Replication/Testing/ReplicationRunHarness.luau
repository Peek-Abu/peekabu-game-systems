--!strict
--[=[
	Replication harness (spec 2026-09-22 §10), ported from the spike's A/B.

	Runs one replication system over a trace through two simulated links (owner → server → viewer) on a
	shared 60 Hz clock, and scores what the viewer RENDERS. The runner knows nothing about either system's
	internals: a system is an adapter with owner / server / viewer hooks that exchange real buffers, so
	byte counts are the real encoded sizes.

	Scoring (the same for every system):
	  latency   the render delay that best explains the viewer's picture: the lag L minimising
	            mean |rendered(t) − truth(t − L)| (searched 0–500 ms). A system that doesn't declare a
	            render time is still measured fairly.
	  fidelity  |rendered(t) − truth(t − L)| at that best lag: the SHAPE error (mean / p95 / p99 / max).
	  present   |rendered(t) − truth(t)|: what a viewer aiming at the body actually misses by (latency +
	            shape).
	  pops      frames where the rendered body jumps > 1 stud more than the (lagged) truth moved — a
	            visible snap. Frames next to a real teleport in the trace are excluded.
	  stalls    frames where the rendered body doesn't move (< 0.01 stud) while the truth moved > 0.15 —
	            a visible freeze.
	  bytes     uplink and downlink payload bytes per second, packets per second, retransmits.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationLinkHarness = require(ReplicatedStorage.Shared.Features.Replication.Testing.ReplicationLinkHarness)
local ReplicationTraceHarness = require(ReplicatedStorage.Shared.Features.Replication.Testing.ReplicationTraceHarness)

export type Outgoing = { payload: buffer, reliable: boolean }

export type System = {
	name: string,
	ownerFrame: (nowMs: number, truth: ReplicationTraceHarness.TruthSample, respawned: boolean) -> { Outgoing },
	serverReceive: (nowMs: number, payload: buffer) -> (),
	serverFrame: (nowMs: number, viewerDistance: number) -> { Outgoing },
	viewerReceive: (nowMs: number, payload: buffer) -> (),
	viewerRender: (nowMs: number) -> Vector3?,
}

export type Result = {
	system: string,
	profile: string,
	latencyMs: number,
	fidelity: { mean: number, p95: number, p99: number, max: number },
	present: { mean: number, p95: number },
	pops: number,
	stalls: number,
	worst: { string }, -- the five largest shape errors: "t=…ms err=… studs"
	rendered: { [number]: Vector3 }, -- per frame, for inspection
	upBytesPerSecond: number,
	downBytesPerSecond: number,
	downPacketsPerSecond: number,
	retransmits: number,
	frames: number,
}

local ReplicationRunHarness = {}

local function percentile(values: { number }, p: number): number
	if #values == 0 then
		return 0
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
end

local WARMUP_FRAMES = 60 -- 1 s for buffers and delay estimators to settle
local TAIL_FRAMES = 40
local TELEPORT_GUARD_MS = 400

export type RunOptions = {
	stallAtMs: number?, -- the viewer stops processing (window in the background) at this time...
	stallForMs: number?, -- ...for this long; packets queue and all land in the next processed frame
}

function ReplicationRunHarness.run(
	system: System,
	trace: ReplicationTraceHarness.Trace,
	profile: ReplicationLinkHarness.Profile,
	seed: number,
	viewerDistance: number,
	options: RunOptions?
): Result
	local frameMs = ReplicationTraceHarness.FRAME_MS
	local stallAtMs = if options ~= nil then options.stallAtMs else nil
	local stallForMs = if options ~= nil and options.stallForMs ~= nil then options.stallForMs else 0
	local up = ReplicationLinkHarness.new(profile, seed)
	local down = ReplicationLinkHarness.new(profile, seed + 7919)
	local samples = trace.samples
	local total = #samples
	local rendered: { [number]: Vector3 } = {}
	local respawnFrames = trace.respawnFrames
	for f = 1, total + TAIL_FRAMES do
		local nowMs = (f - 1) * frameMs
		local truth = samples[math.min(f, total)]
		if f <= total then
			for _, out in system.ownerFrame(nowMs, truth, respawnFrames[f] == true) do
				if out.reliable then
					ReplicationLinkHarness.sendReliable(up, nowMs, out.payload)
				else
					ReplicationLinkHarness.sendUnreliable(up, nowMs, out.payload)
				end
			end
		end
		for _, payload in ReplicationLinkHarness.receive(up, nowMs) do
			system.serverReceive(nowMs, payload)
		end
		for _, out in system.serverFrame(nowMs, viewerDistance) do
			if out.reliable then
				ReplicationLinkHarness.sendReliable(down, nowMs, out.payload)
			else
				ReplicationLinkHarness.sendUnreliable(down, nowMs, out.payload)
			end
		end
		local viewerStalled = stallAtMs ~= nil and nowMs >= stallAtMs and nowMs < stallAtMs + stallForMs
		if not viewerStalled then
			for _, payload in ReplicationLinkHarness.receive(down, nowMs) do
				system.viewerReceive(nowMs, payload)
			end
			local position = system.viewerRender(nowMs)
			if position ~= nil then
				rendered[f] = position
			end
		end
	end

	-- Frames that are near a real teleport in the truth (excluded from pops / stalls / fidelity peaks).
	local teleportTimes: { number } = {}
	for frame in trace.teleportFrames do
		table.insert(teleportTimes, (frame - 1) * frameMs)
	end
	local function nearTeleport(tMs: number): boolean
		for _, teleportMs in teleportTimes do
			if math.abs(tMs - teleportMs) < TELEPORT_GUARD_MS then
				return true
			end
		end
		return false
	end

	local lastMs = (total - 1) * frameMs
	local function meanErrorAt(lagMs: number): number
		local sum, n = 0, 0
		for f = WARMUP_FRAMES, total do
			local position: Vector3? = rendered[f]
			local tMs = (f - 1) * frameMs - lagMs
			if position ~= nil and tMs >= 0 and tMs <= lastMs and not nearTeleport(tMs) then
				sum += (position - ReplicationTraceHarness.at(trace, tMs)).Magnitude
				n += 1
			end
		end
		return if n > 0 then sum / n else math.huge
	end
	local bestLag, bestError = 0, math.huge
	for lag = 0, 500, 2 do
		local e = meanErrorAt(lag)
		if e < bestError then
			bestLag, bestError = lag, e
		end
	end

	local shape: { number } = {}
	local worstFrames: { { tMs: number, err: number } } = {}
	local presentErrors: { number } = {}
	local pops, stalls = 0, 0
	for f = WARMUP_FRAMES, total do
		local position: Vector3? = rendered[f]
		local nowMs = (f - 1) * frameMs
		local tMs = nowMs - bestLag
		if position ~= nil and tMs >= 0 then
			local guarded = nearTeleport(tMs) or nearTeleport(tMs - frameMs)
			if not guarded then
				local err = (position - ReplicationTraceHarness.at(trace, tMs)).Magnitude
				table.insert(shape, err)
				table.insert(worstFrames, { tMs = nowMs, err = err })
			end
			if not nearTeleport(nowMs) then
				table.insert(presentErrors, (position - ReplicationTraceHarness.at(trace, nowMs)).Magnitude)
			end
			local previous: Vector3? = rendered[f - 1]
			if previous ~= nil and not guarded and tMs - frameMs >= 0 then
				local renderedStep = (position - previous).Magnitude
				local truthStep = (ReplicationTraceHarness.at(trace, tMs) - ReplicationTraceHarness.at(
					trace,
					tMs - frameMs
				)).Magnitude
				if renderedStep > truthStep + 1 then
					pops += 1
				end
				if renderedStep < 0.01 and truthStep > 0.15 then
					stalls += 1
				end
			end
		end
	end
	table.sort(worstFrames, function(a, b)
		return a.err > b.err
	end)
	local worst: { string } = {}
	for i = 1, math.min(5, #worstFrames) do
		table.insert(worst, string.format("t=%.0fms err=%.2f", worstFrames[i].tMs, worstFrames[i].err))
	end
	local seconds = total * frameMs / 1000
	local mean = 0
	for _, e in shape do
		mean += e
	end
	mean = if #shape > 0 then mean / #shape else 0
	local presentMean = 0
	for _, e in presentErrors do
		presentMean += e
	end
	presentMean = if #presentErrors > 0 then presentMean / #presentErrors else 0
	return {
		system = system.name,
		profile = profile.name,
		latencyMs = bestLag,
		fidelity = {
			mean = mean,
			p95 = percentile(shape, 0.95),
			p99 = percentile(shape, 0.99),
			max = percentile(shape, 1),
		},
		present = { mean = presentMean, p95 = percentile(presentErrors, 0.95) },
		pops = pops,
		stalls = stalls,
		worst = worst,
		rendered = rendered,
		upBytesPerSecond = up.bytesSent / seconds,
		downBytesPerSecond = down.bytesSent / seconds,
		downPacketsPerSecond = down.packetsSent / seconds,
		retransmits = up.retransmits + down.retransmits,
		frames = total,
	}
end

return ReplicationRunHarness
