--!strict
--[=[
	Per-viewer render delay controller (spec 2026-09-22 §6.6, as superseded by the Verdict: the "v3" clock
	measured in the spike's A/B).

	The delay a viewer renders remote bodies behind real time is chosen from what this viewer measures:

	  target = p95(lateness of NEW samples) + (lossLevel + 1) × frame + margin

	retargeted every 250 ms with hysteresis. The delay jumps up when the target is far above or the renderer is
	starving, glides up otherwise, and falls slowly. It never exceeds `maxDelayMs`, and never renders further back
	than the sample buffers reach (`reachMs`, from `ReplicationSampleTracker.reachMs`).

	Two developer-run findings are built in:
	  - Resends and repairs carry OLD samples: only samples newer than the buffer's newest vote on lateness.
	  - A local stall (window in the background, a long frame) makes the backlog look late. Batches processed
	    within `stallBlockMs` after a frame gap over `localStallMs` (and `stallFactor` × the median recent gap), or before the stalled frame is noted, feed
	    the buffer but do not vote.

	Pure: time is passed in (ms), so client code and specs drive it the same way.

	@class ReplicationRenderClockSystem
]=]

local ReplicationRenderClockSystem = {}

export type Config = {
	frameMs: number,
	latenessPct: number,
	spacingIntervals: number,
	marginMs: number,
	riseMsPerSecond: number,
	fallMsPerSecond: number,
	hysteresisMs: number,
	jumpAboveMs: number,
	maxDelayMs: number,
	initialDelayMs: number,
	window: number,
	lossWindow: number,
	retargetMs: number,
	maxLatenessMs: number,
	localStallMs: number,
	stallBlockMs: number,
	frameWindow: number,
	stallFactor: number,
}

local DEFAULT_CONFIG: Config = {
	frameMs = 1000 / 60,
	latenessPct = 0.95,
	spacingIntervals = 1,
	marginMs = 4,
	riseMsPerSecond = 60,
	fallMsPerSecond = 15,
	hysteresisMs = 6,
	jumpAboveMs = 25,
	maxDelayMs = 600,
	initialDelayMs = 100,
	window = 240,
	lossWindow = 240,
	retargetMs = 250,
	maxLatenessMs = 1000,
	localStallMs = 100,
	stallBlockMs = 100,
	frameWindow = 31,
	stallFactor = 4,
}
table.freeze(DEFAULT_CONFIG)
ReplicationRenderClockSystem.DEFAULT_CONFIG = DEFAULT_CONFIG

export type Clock = {
	config: Config,
	lateness: { number },
	latenessIndex: number,
	lossSteps: { number },
	lossIndex: number,
	lastSeq: number?,
	lossLevel: number,
	delayMs: number,
	targetMs: number,
	sinceRetargetMs: number,
	lastAdvanceMs: number?,
	lastFrameMs: number?,
	frameGaps: { number },
	frameGapIndex: number,
	blockedUntilMs: number,
	skipped: number,
}

function ReplicationRenderClockSystem.new(config: Config?): Clock
	local cfg = config or DEFAULT_CONFIG
	return {
		config = cfg,
		lateness = {},
		latenessIndex = 0,
		lossSteps = {},
		lossIndex = 0,
		lastSeq = nil,
		lossLevel = 0,
		delayMs = cfg.initialDelayMs,
		targetMs = cfg.initialDelayMs,
		sinceRetargetMs = 0,
		lastAdvanceMs = nil,
		lastFrameMs = nil,
		frameGaps = {},
		frameGapIndex = 0,
		blockedUntilMs = -math.huge,
		skipped = 0,
	}
end

local function percentile(values: { number }, p: number): number
	if #values == 0 then
		return 0
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
end

-- A frame gap counts as a stall when it exceeds `localStallMs` AND `stallFactor` × the recent median gap, so a
-- steady low-FPS client (every gap long) still adapts instead of being treated as permanently stalled.
local function stallThresholdMs(clock: Clock): number
	local cfg = clock.config
	local gaps = clock.frameGaps
	if #gaps == 0 then
		return cfg.localStallMs
	end
	return math.max(cfg.localStallMs, cfg.stallFactor * percentile(gaps, 0.5))
end

local function stalled(clock: Clock, nowMs: number): boolean
	local lastFrame = clock.lastFrameMs
	return nowMs < clock.blockedUntilMs or (lastFrame ~= nil and nowMs - lastFrame > stallThresholdMs(clock))
end

--[=[
	Once per rendered frame, before `advance`. A frame gap over `localStallMs` blocks lateness voting for
	`stallBlockMs`.
]=]
function ReplicationRenderClockSystem.noteFrame(clock: Clock, nowMs: number)
	local lastFrame = clock.lastFrameMs
	if lastFrame ~= nil then
		local gap = nowMs - lastFrame
		if gap > stallThresholdMs(clock) then
			clock.blockedUntilMs = nowMs + clock.config.stallBlockMs
		end
		clock.frameGapIndex = clock.frameGapIndex % clock.config.frameWindow + 1
		clock.frameGaps[clock.frameGapIndex] = math.min(gap, 1000)
	end
	clock.lastFrameMs = nowMs
end

--[=[
	Per received batch. `latenessMs` is arrival time minus a new sample's time — with several bodies in one
	batch, the LARGEST among the batch's new samples. `isNewSample` is whether any record in the batch was
	new to its buffer (`ReplicationSampleTracker.isNewSample` of what `push` returned); false for a batch of
	resends or repairs whose samples the buffers already hold, which must not vote on lateness.

	Loss level: each forward seq step is recorded and the margin level counts loss OR reorder. A batch that
	arrives after a later one (a gap filled late) is still a late batch, so it is NOT taken back: the gap it
	left stays counted. Measured on the mobile profile, taking it back dropped the margin and raised the mean
	error from 0.104 to 0.175. A duplicate or an arrival behind the newest seq changes nothing.
]=]
function ReplicationRenderClockSystem.onBatch(
	clock: Clock,
	nowMs: number,
	seq: number,
	latenessMs: number,
	isNewSample: boolean
)
	local cfg = clock.config
	local lastSeq = clock.lastSeq
	if lastSeq == nil then
		clock.lastSeq = seq
	else
		local step = (seq - lastSeq) % 65536
		if step > 0 and step < 1000 then
			clock.lossIndex = clock.lossIndex % cfg.lossWindow + 1
			clock.lossSteps[clock.lossIndex] = step
			clock.lastSeq = seq
		elseif step >= 1000 and step < 32768 then
			clock.lastSeq = seq
		end
	end
	if not isNewSample then
		return
	end
	if stalled(clock, nowMs) then
		clock.skipped += 1 -- before the lateness cap: a stall backlog is mostly over 1 s late and must be counted
		return
	end
	if latenessMs >= cfg.maxLatenessMs then
		return
	end
	clock.latenessIndex = clock.latenessIndex % cfg.window + 1
	clock.lateness[clock.latenessIndex] = latenessMs
end

local function retarget(clock: Clock)
	local cfg = clock.config
	local expected = 0
	for _, step in clock.lossSteps do
		expected += step
	end
	local lossRate = if expected > 0 then 1 - #clock.lossSteps / expected else 0
	clock.lossLevel = if lossRate > 0.06 then 2 elseif lossRate > 0.015 then 1 else 0
	if #clock.lateness == 0 then
		return
	end
	local candidate = percentile(clock.lateness, cfg.latenessPct)
		+ (clock.lossLevel + cfg.spacingIntervals) * cfg.frameMs
		+ cfg.marginMs
	if math.abs(candidate - clock.targetMs) >= cfg.hysteresisMs then
		clock.targetMs = candidate
	end
end

--[=[
	Once per rendered frame. `starving` is whether last frame's evaluation was in `hold` — samples genuinely
	late (`ReplicationSampleTracker.isStarving`). `behind` is NOT starving: render time older than the buffer
	means the delay is too large, and `reachMs` (the smallest `ReplicationSampleTracker.reachMs` across visible
	bodies) brings it forward. Returns the delay.
]=]
function ReplicationRenderClockSystem.advance(clock: Clock, nowMs: number, starving: boolean, reachMs: number): number
	local cfg = clock.config
	local lastAdvance = clock.lastAdvanceMs
	local dtMs = if lastAdvance ~= nil then math.clamp(nowMs - lastAdvance, 0, 100) else 0
	clock.lastAdvanceMs = nowMs
	clock.sinceRetargetMs += dtMs
	if clock.sinceRetargetMs >= cfg.retargetMs then
		clock.sinceRetargetMs = 0
		retarget(clock)
	end
	local target = math.min(clock.targetMs, cfg.maxDelayMs, reachMs)
	if target > clock.delayMs then
		local jump = starving or target - clock.delayMs > cfg.jumpAboveMs
		clock.delayMs = if jump then target else math.min(target, clock.delayMs + cfg.riseMsPerSecond * dtMs / 1000)
	elseif clock.delayMs > reachMs or clock.delayMs > cfg.maxDelayMs then
		clock.delayMs = target -- the buffers can't serve this delay: come forward at once
	else
		clock.delayMs = math.max(target, clock.delayMs - cfg.fallMsPerSecond * dtMs / 1000)
	end
	return clock.delayMs
end

export type Stats = {
	latenessP50Ms: number,
	latenessP95Ms: number,
	latenessMaxMs: number,
	latenessCount: number,
	targetMs: number,
	skipped: number,
	frameGapMedianMs: number,
	stallThresholdMs: number,
}

--[=[
	Read-only diagnostics for the F4 panel: what feeds the delay. Allocates; call it from a debug read, never per frame.
]=]
function ReplicationRenderClockSystem.stats(clock: Clock): Stats
	local maxLateness = 0
	for _, value in clock.lateness do
		maxLateness = math.max(maxLateness, value)
	end
	return {
		latenessP50Ms = percentile(clock.lateness, 0.5),
		latenessP95Ms = percentile(clock.lateness, clock.config.latenessPct),
		latenessMaxMs = maxLateness,
		latenessCount = #clock.lateness,
		targetMs = clock.targetMs,
		skipped = clock.skipped,
		frameGapMedianMs = percentile(clock.frameGaps, 0.5),
		stallThresholdMs = stallThresholdMs(clock),
	}
end

return ReplicationRenderClockSystem
