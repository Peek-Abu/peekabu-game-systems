--!strict
--[=[
	Character interpolator (spec 2026-09-22 §6.6, §6.7; measured in the spike's CP4 and A/B).

	Per-body sample buffer + cubic Hermite evaluation using the SENT velocity (spec §6.6):
	- time-normalised tangents `m = v × Δt`, capped at `1.5·chord + 0.25`;
	- on a segment where `grounded` flips, tangents are clamped to the chord (no overshoot into the
	  floor on landing);
	- past the newest sample: dead-reckon from its velocity for ≤ 100 ms, then hold;
	- CP6 ragdoll samples carry a full `rotation` (and no velocity): position is linear between them
	  (zero-velocity Hermite would ease-in/out every segment — a 60 Hz stutter) and rotation slerps.
	Pure: no Roblox services, so the server can evaluate exactly what a viewer rendered (lag comp).

	@class ReplicationSampleTracker
]=]

local ReplicationSampleTracker = {}

-- 32 samples = 533 ms of 60 Hz history: the render clock's delay (up to ~330 ms on a mobile link) must stay
-- inside what the buffer holds (Verdict: "never further back than a full buffer reaches").
local MAX_SAMPLES = 32
local GRAVITY = 185
ReplicationSampleTracker.MAX_SAMPLES = MAX_SAMPLES
ReplicationSampleTracker.GRAVITY = GRAVITY
local MAX_EXTRAPOLATE_MS = 100

export type Sample = {
	timeMs: number,
	position: Vector3,
	velocity: Vector3,
	yaw: number,
	state: number,
	grounded: boolean,
	rotation: CFrame?,
}

export type Buffer = {
	samples: { Sample },
	epoch: number,
}

export type Mode = "interpolate" | "extrapolate" | "hold" | "behind" | "empty"

export type Evaluation = {
	position: Vector3,
	velocity: Vector3,
	yaw: number,
	state: number,
	grounded: boolean,
	rotation: CFrame?,
	-- "behind": renderTime is OLDER than the oldest buffered sample (delay too large) — NOT lateness.
	-- "hold": past the newest sample beyond the extrapolation window (samples genuinely late).
	mode: Mode,
}

function ReplicationSampleTracker.newBuffer(): Buffer
	return { samples = {}, epoch = -1 }
end

--[=[
	What `push` did with a sample:
	  newest    appended as the buffer's newest sample;
	  inserted  accepted, but older than the newest (a reordered record or a resend of a missed one);
	  flushed   the next epoch (current + 1 mod 8) emptied the buffer and this is now its only sample;
	  dropped   a duplicate time, a straggler from any other epoch, or older than a full buffer holds.
	Only `newest` and `flushed` are NEW samples for the render clock's lateness (`isNewSample`).
]=]
export type PushResult = "newest" | "inserted" | "flushed" | "dropped"

--[=[
	Insert a sample in time order. The next epoch (current + 1 mod 8) flushes the buffer (teleport /
	respawn); a record from any other epoch is dropped — the reliable slot table resets a buffer that
	missed a bump (`resetEpoch`).
]=]
function ReplicationSampleTracker.push(b: Buffer, epoch: number, sample: Sample): PushResult
	local flushed = false
	if epoch ~= b.epoch then
		if b.epoch >= 0 and epoch ~= (b.epoch + 1) % 8 then
			return "dropped"
		end
		b.epoch = epoch
		table.clear(b.samples)
		flushed = true
	end
	local samples = b.samples
	local index = #samples + 1
	while index > 1 and samples[index - 1].timeMs >= sample.timeMs do
		if samples[index - 1].timeMs == sample.timeMs then
			return "dropped"
		end
		index -= 1
	end
	local newest = index == #samples + 1
	table.insert(samples, index, sample)
	local trimmed = 0
	while #samples > MAX_SAMPLES do
		table.remove(samples, 1)
		trimmed += 1
	end
	if flushed then
		return "flushed"
	end
	if index <= trimmed then
		return "dropped" -- older than everything a full buffer keeps: it was trimmed straight away
	end
	return if newest then "newest" else "inserted"
end

function ReplicationSampleTracker.isNewSample(result: PushResult): boolean
	return result == "newest" or result == "flushed"
end

--[=[
	Empty the buffer and adopt `epoch` (the slot table's full epoch; the wire carries its low 3 bits).
	Used when the reliable slot table announces an epoch the buffer would otherwise never accept (a lost
	bump), and when a body re-enters relevance (a fresh buffer, so it never slides from old samples).
]=]
function ReplicationSampleTracker.resetEpoch(b: Buffer, epoch: number)
	b.epoch = epoch % 8
	table.clear(b.samples)
end

--[=[
	Whether an evaluation means the samples are late: `hold` only. `behind` (render time older than the
	buffer) means the delay is too large — `ReplicationRenderClockSystem.advance`'s reach brings it forward — and must
	never raise the delay.
]=]
function ReplicationSampleTracker.isStarving(mode: Mode): boolean
	return mode == "hold"
end

local function clampTangent(m: Vector3, chord: Vector3): Vector3
	local cap = 1.5 * chord.Magnitude + 0.25
	local length = m.Magnitude
	if length > cap and length > 0 then
		return m * (cap / length)
	end
	return m
end

local function lerpAngle(a: number, b: number, t: number): number
	local delta = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + delta * t
end

--[=[
	Hermite between two samples at `timeMs` (between their times).
]=]
function ReplicationSampleTracker.hermite(a: Sample, b: Sample, timeMs: number): (Vector3, Vector3)
	local spanMs = b.timeMs - a.timeMs
	if spanMs <= 0 then
		return b.position, b.velocity
	end
	local s = math.clamp((timeMs - a.timeMs) / spanMs, 0, 1)
	local dt = spanMs / 1000
	local chord = b.position - a.position
	local m0 = clampTangent(a.velocity * dt, chord)
	local m1 = clampTangent(b.velocity * dt, chord)
	if a.grounded ~= b.grounded then
		-- Contact change (take-off / landing): keep the curve inside the chord.
		m0 = chord
		m1 = chord
	end
	local s2 = s * s
	local s3 = s2 * s
	local h00 = 2 * s3 - 3 * s2 + 1
	local h10 = s3 - 2 * s2 + s
	local h01 = -2 * s3 + 3 * s2
	local h11 = s3 - s2
	local position = a.position * h00 + m0 * h10 + b.position * h01 + m1 * h11
	-- Derivative for the animation speed.
	local d00 = 6 * s2 - 6 * s
	local d10 = 3 * s2 - 4 * s + 1
	local d01 = -6 * s2 + 6 * s
	local d11 = 3 * s2 - 2 * s
	local velocity = (a.position * d00 + m0 * d10 + b.position * d01 + m1 * d11) / dt
	return position, velocity
end

--[=[
	The per-frame fast path (A/B harness finding: `evaluate` cost 1.15 µs/body-frame against an alternative
	technique's 0.45). Same curve as `evaluate`, but it allocates no result table, skips the derivative, yaw and
	state work, and resumes the bracket search from a caller-owned hint (render time only moves forward, so
	the bracket is almost always the one from last frame).
]=]
export type Hint = { index: number }

function ReplicationSampleTracker.newHint(): Hint
	return { index = 1 }
end

function ReplicationSampleTracker.evaluatePosition(b: Buffer, timeMs: number, hint: Hint): (Vector3, Mode)
	local samples = b.samples
	local count = #samples
	if count == 0 then
		return Vector3.zero, "empty"
	end
	local first = samples[1]
	if timeMs <= first.timeMs then
		return first.position, "behind"
	end
	local last = samples[count]
	if timeMs >= last.timeMs then
		local aheadMs = timeMs - last.timeMs
		local mode: "extrapolate" | "hold" = if aheadMs <= MAX_EXTRAPOLATE_MS then "extrapolate" else "hold"
		return last.position + last.velocity * (math.min(aheadMs, MAX_EXTRAPOLATE_MS) / 1000), mode
	end
	local i = math.clamp(hint.index, 1, count - 1)
	while i > 1 and samples[i].timeMs > timeMs do
		i -= 1
	end
	while i < count - 1 and samples[i + 1].timeMs <= timeMs do
		i += 1
	end
	hint.index = i
	local a, c = samples[i], samples[i + 1]
	local spanMs = c.timeMs - a.timeMs
	local s = if spanMs > 0 then (timeMs - a.timeMs) / spanMs else 1
	if a.rotation ~= nil and c.rotation ~= nil then
		return a.position:Lerp(c.position, s), "interpolate"
	end
	local dt = spanMs / 1000
	local chord = c.position - a.position
	local m0, m1
	if a.grounded ~= c.grounded then
		m0, m1 = chord, chord
	else
		m0 = clampTangent(a.velocity * dt, chord)
		m1 = clampTangent(c.velocity * dt, chord)
	end
	local s2 = s * s
	local s3 = s2 * s
	return a.position * (2 * s3 - 3 * s2 + 1) + m0 * (s3 - 2 * s2 + s) + c.position * (3 * s2 - 2 * s3) + m1 * (s3 - s2),
		"interpolate"
end

--[=[
	`evaluatePosition` plus the yaw, for the per-frame puppet placement: allocation-free, same curve.
	Yaw is the shortest-arc blend across the bracket, or the edge sample's yaw outside it.
]=]
function ReplicationSampleTracker.evaluatePose(b: Buffer, timeMs: number, hint: Hint): (Vector3, number, Mode)
	-- Annotated: Luau widens the singleton-union return to `string` on an unannotated local.
	local position: Vector3, mode: Mode = ReplicationSampleTracker.evaluatePosition(b, timeMs, hint)
	local samples = b.samples
	local count = #samples
	if count == 0 then
		return position, 0, mode
	end
	if mode ~= "interpolate" then
		local edge = if mode == "behind" then samples[1] else samples[count]
		return position, edge.yaw, mode
	end
	local a, c = samples[hint.index], samples[hint.index + 1]
	local spanMs = c.timeMs - a.timeMs
	local s = if spanMs > 0 then (timeMs - a.timeMs) / spanMs else 1
	return position, lerpAngle(a.yaw, c.yaw, s), mode
end

--[=[
	The movement state at `timeMs` for puppet animation (R3): the NEAREST sample's state, grounded flag and
	sent velocity (the nearest-sample rule `evaluate` uses for state); past the newest sample the newest,
	before the oldest the oldest. Allocation-free; shares `evaluatePose`'s hint.
]=]
function ReplicationSampleTracker.motionAt(b: Buffer, timeMs: number, hint: Hint): (number, boolean, Vector3)
	local samples = b.samples
	local count = #samples
	if count == 0 then
		return 0, true, Vector3.zero
	end
	local first = samples[1]
	if timeMs <= first.timeMs then
		return first.state, first.grounded, first.velocity
	end
	local last = samples[count]
	if timeMs >= last.timeMs then
		return last.state, last.grounded, last.velocity
	end
	local i = math.clamp(hint.index, 1, count - 1)
	while i > 1 and samples[i].timeMs > timeMs do
		i -= 1
	end
	while i < count - 1 and samples[i + 1].timeMs <= timeMs do
		i += 1
	end
	hint.index = i
	local a, c = samples[i], samples[i + 1]
	local nearest = if timeMs - a.timeMs < c.timeMs - timeMs then a else c
	return nearest.state, nearest.grounded, nearest.velocity
end

function ReplicationSampleTracker.evaluate(b: Buffer, timeMs: number): Evaluation
	local samples = b.samples
	local count = #samples
	if count == 0 then
		return {
			position = Vector3.zero,
			velocity = Vector3.zero,
			yaw = 0,
			state = 0,
			grounded = true,
			mode = "empty",
		}
	end
	local first = samples[1]
	if timeMs <= first.timeMs then
		return {
			position = first.position,
			velocity = first.velocity,
			yaw = first.yaw,
			state = first.state,
			grounded = first.grounded,
			rotation = first.rotation,
			mode = "behind",
		}
	end
	local last = samples[count]
	if timeMs >= last.timeMs then
		local aheadMs = math.min(timeMs - last.timeMs, MAX_EXTRAPOLATE_MS)
		return {
			position = last.position + last.velocity * (aheadMs / 1000),
			velocity = last.velocity,
			yaw = last.yaw,
			state = last.state,
			grounded = last.grounded,
			rotation = last.rotation,
			mode = if timeMs - last.timeMs <= MAX_EXTRAPOLATE_MS then "extrapolate" else "hold",
		}
	end
	for i = count - 1, 1, -1 do
		local a = samples[i]
		if a.timeMs <= timeMs then
			local nextSample = samples[i + 1]
			local s = (timeMs - a.timeMs) / math.max(nextSample.timeMs - a.timeMs, 1)
			local fromRotation, toRotation = a.rotation, nextSample.rotation
			local position, velocity
			local rotation: CFrame? = nil
			if fromRotation ~= nil and toRotation ~= nil then
				position = a.position:Lerp(nextSample.position, s)
				velocity = (nextSample.position - a.position) / math.max((nextSample.timeMs - a.timeMs) / 1000, 1e-3)
				rotation = fromRotation:Lerp(toRotation, s)
			else
				position, velocity = ReplicationSampleTracker.hermite(a, nextSample, timeMs)
				rotation = if s < 0.5 then fromRotation else toRotation
			end
			return {
				position = position,
				velocity = velocity,
				yaw = lerpAngle(a.yaw, nextSample.yaw, s),
				state = if s < 0.5 then a.state else nextSample.state,
				grounded = if s < 0.5 then a.grounded else nextSample.grounded,
				rotation = rotation,
				mode = "interpolate",
			}
		end
	end
	return {
		position = last.position,
		velocity = last.velocity,
		yaw = last.yaw,
		state = last.state,
		grounded = last.grounded,
		rotation = last.rotation,
		mode = "hold",
	}
end

--[=[
	State-aware dead reckoning past the newest sample (A/B finding: a lost landing packet used to draw the body
	through the floor at 180 studs/s). Horizontal motion continues at the sent velocity; an airborne body falls
	under gravity and stops at `groundBelow` (the viewer's downward raycast); with no world query, an airborne
	body is never extrapolated downward. At most `maxAheadMs` past the newest sample. `groundBelow` returns the
	ground height under the position, or `-math.huge` when nothing is hit.
]=]
function ReplicationSampleTracker.reckon(
	b: Buffer,
	timeMs: number,
	maxAheadMs: number,
	groundBelow: ((position: Vector3) -> number)?
): Vector3?
	local newest = b.samples[#b.samples]
	if newest == nil then
		return nil
	end
	local ahead = math.clamp(timeMs - newest.timeMs, 0, maxAheadMs) / 1000
	local v = newest.velocity
	local position = newest.position + Vector3.new(v.X, 0, v.Z) * ahead
	local y = if newest.grounded
		then newest.position.Y
		else newest.position.Y + v.Y * ahead - 0.5 * GRAVITY * ahead * ahead
	if groundBelow ~= nil then
		y = math.max(y, groundBelow(Vector3.new(position.X, newest.position.Y, position.Z)))
	elseif not newest.grounded and y < newest.position.Y then
		y = newest.position.Y
	end
	return Vector3.new(position.X, y, position.Z)
end

function ReplicationSampleTracker.newestTimeMs(b: Buffer): number?
	local newest = b.samples[#b.samples]
	return if newest ~= nil then newest.timeMs else nil
end

--[=[
	How far back from `nowMs` this buffer can still be rendered. Unlimited until the buffer is full (a body that
	just appeared must not drag the render clock down); once full, the oldest sample's age.
]=]
function ReplicationSampleTracker.reachMs(b: Buffer, nowMs: number): number
	local samples = b.samples
	if #samples < MAX_SAMPLES then
		return math.huge
	end
	return nowMs - samples[1].timeMs
end

return ReplicationSampleTracker
