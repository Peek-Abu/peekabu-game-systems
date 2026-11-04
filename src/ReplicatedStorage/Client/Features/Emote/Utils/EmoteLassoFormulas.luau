--!strict
--[=[
	EmoteLassoFormulas: the pure maths of Sheriff Prickles' bendy lasso (EmoteLassoSystem draws it).

	The clip still poses the rigid LassoLoop prop; it is only a driver. From it each substep moves:
	- the rope: a verlet chain from the hand (pinned, leaving it straight along the clip's rope) to the knot, its length
	  held, every joint's bend limited (the crumple fix), light gravity, a weak pull to the clip's line;
	- the loop: a verlet ring through the knot, its length held, weak pulls to the clip's ring (strong by the knot, weak
	  on the far side, so the far side trails), and an outward pull that holds it open while it spins;
	- a wrist circle: the knot rides a small breathing circle, so the rope sweeps a cone instead of standing still on
	  the clip's spin axis;
	- the faster spin: the loop turns spinMul x the clip's rate while the rope stands up, on a clock as much faster
	  (pulls x spinMul^2, damping x spinMul);
	- the throw: once the rope has stood up, tipping it toward his facing sends the knot out and reels it back.
	`step` returns a new State; nothing here keeps or changes anything else. Numbers: EmoteLassoConstants. The
	offline twin, tuned on the clip's own motion: characters/launch/animation-workbench/workflow/bendy-lasso-2026-11-03.

	@class EmoteLassoFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteLassoConstants = require(ReplicatedStorage.Client.Features.Emote.Data.EmoteLassoConstants)

type Tuning = EmoteLassoConstants.Tuning

-- The clip's pose of the lasso this substep, in world space.
export type Driver = {
	grip: Vector3,
	up: Vector3,
	-- From the ring's centre toward the knot.
	side: Vector3,
	knot: Vector3,
	-- His facing, flat.
	facing: Vector3,
	-- The prop's size over its template's.
	scale: number,
}

export type State = {
	live: boolean,
	-- rope[1] is the hand, rope[#rope] the knot (= ring[1]).
	rope: { Vector3 },
	ropePrev: { Vector3 },
	ring: { Vector3 },
	ringPrev: { Vector3 },
	clock: number,
	-- Seconds the rope has stood up, the last tip toward his facing, and when the throw began.
	upright: number,
	lastTip: number,
	throwAt: number?,
	-- The extra turn (radians) the faster spin has added, and the clip's side direction last substep.
	spin: number,
	sidePrev: Vector3?,
}

local EmoteLassoFormulas = {}

--[=[
	A lasso not yet drawn: the first step lays it out on the clip's pose.
]=]
function EmoteLassoFormulas.newState(): State
	return {
		live = false,
		rope = {},
		ropePrev = {},
		ring = {},
		ringPrev = {},
		clock = 0,
		upright = 0,
		lastTip = 0,
		throwAt = nil,
		spin = 0,
		sidePrev = nil,
	}
end

--[=[
	The clip's lasso pose from the LassoLoop part's CFrame, its height and his look direction.
]=]
function EmoteLassoFormulas.driverOf(cf: CFrame, height: number, look: Vector3): Driver
	local scale = height / EmoteLassoConstants.TEMPLATE_HEIGHT
	local flat = Vector3.new(look.X, 0, look.Z)
	return {
		grip = cf:PointToWorldSpace(EmoteLassoConstants.GRIP * scale),
		up = cf.UpVector,
		side = cf.RightVector,
		knot = cf:PointToWorldSpace(EmoteLassoConstants.KNOT * scale),
		facing = if flat.Magnitude > 1e-6 then flat.Unit else Vector3.new(0, 0, -1),
		scale = scale,
	}
end

--[=[
	How far out the throw is (0..1), `t` seconds after it began: out with an ease, held, then reeled back.
]=]
function EmoteLassoFormulas.reachAt(t: number, tuning: Tuning): number
	local out, hold, back = tuning.throwOut, tuning.throwHold, tuning.throwBack
	if t < 0 then
		return 0
	elseif t < out then
		return 1 - (1 - t / out) ^ 3
	elseif t < out + hold then
		return 1
	elseif t < out + hold + back then
		return 1 - ((t - out - hold) / back) ^ 2
	end
	return 0
end

-- `v` with any part along the unit `axis` removed.
local function flatten(v: Vector3, axis: Vector3): Vector3
	return v - axis * v:Dot(axis)
end

--[=[
	One substep of `dt` seconds: the lasso moved toward `driver`'s pose. Returns the new State.
]=]
function EmoteLassoFormulas.step(state: State, driver: Driver, dt: number, tuning: Tuning): State
	local M, K = tuning.ropePoints, tuning.ringPoints
	local k = driver.scale
	local up, grip = driver.up, driver.grip
	local clock = state.clock + dt

	-- The faster spin: (spinMul - 1) x the clip's own turn about the rope, while the rope stands up.
	local m = tuning.spinMul
	local spin = state.spin
	local sidePrev = state.sidePrev
	if sidePrev ~= nil and up.Y > 0.9 then
		local a = flatten(sidePrev, up)
		local c = flatten(driver.side, up)
		spin += (m - 1) * math.atan2(a:Cross(c):Dot(up), a:Dot(c))
	end
	local side = CFrame.fromAxisAngle(up, spin):VectorToWorldSpace(driver.side)
	local m2 = m * m

	-- The throw: armed once the rope has stood up, started when it tips toward his facing.
	local upright = if up.Y > 0.9 then state.upright + dt else state.upright
	local tip = up:Dot(driver.facing)
	local throwAt = state.throwAt
	if throwAt == nil and tip > tuning.tipOn and state.lastTip <= tuning.tipOn and upright > tuning.armSeconds then
		throwAt = clock
	end
	local reach = if throwAt ~= nil then EmoteLassoFormulas.reachAt(clock - throwAt, tuning) else 0
	local throwing = throwAt ~= nil and clock - throwAt < 1

	-- Targets: the knot on its wrist circle (or thrown out), the ring round it, the rope on the line between.
	local wrist = tuning.wrist + tuning.wristWobble * (math.sin(1.7 * clock) + 0.6 * math.sin(3.1 * clock + 1))
	local knotT = driver.knot
		+ side * wrist * k * (1 - reach)
		+ (driver.facing * tuning.reach + Vector3.new(0, tuning.lift, 0)) * k * reach
	local centre = knotT - side * tuning.ringRadius * k
	local across = up:Cross(side)
	local ringT: { Vector3 } = table.create(K)
	for i = 1, K do
		local th = 2 * math.pi * (i - 1) / K
		ringT[i] = centre + (side * math.cos(th) + across * math.sin(th)) * tuning.ringRadius * k
	end
	local function ropeTarget(i: number): Vector3
		return grip:Lerp(knotT, (i - 1) / M)
	end

	local rope, ropePrev, ring, ringPrev
	if state.live then
		rope, ropePrev = table.clone(state.rope), table.clone(state.ropePrev)
		ring, ringPrev = table.clone(state.ring), table.clone(state.ringPrev)
	else
		rope, ropePrev, ring, ringPrev = {}, {}, {}, {}
		for i = 1, M + 1 do
			rope[i] = ropeTarget(i)
			ropePrev[i] = rope[i]
		end
		for i = 1, K do
			ring[i] = ringT[i]
			ringPrev[i] = ringT[i]
		end
		ring[1] = rope[M + 1]
		ringPrev[1] = ring[1]
	end

	-- Integrate: verlet with damping, a speed cap, gravity and the pulls.
	local damp = math.exp(-tuning.damping * m * dt)
	local gravity = Vector3.new(0, -tuning.gravity * k, 0)
	local maxStep = tuning.maxSpeed * k * dt
	local function integrate(p: Vector3, q: Vector3, target: Vector3, pull: number, push: Vector3): Vector3
		local v = (p - q) * damp
		if v.Magnitude > maxStep then
			v = v.Unit * maxStep
		end
		return p + v + (gravity + (target - p) * pull + push) * dt * dt
	end
	local centroid = Vector3.zero
	for i = 1, K do
		centroid += ring[i]
	end
	centroid /= K
	for i = 2, M do
		local nextP = integrate(
			rope[i],
			ropePrev[i],
			ropeTarget(i),
			tuning.pullRope * m2 * (1 + tuning.throwPull * reach),
			Vector3.zero
		)
		ropePrev[i], rope[i] = rope[i], nextP
	end
	do
		local knotPull = tuning.pullKnot * m2 * (if throwing then tuning.throwKnot else 1)
		local nextP = integrate(rope[M + 1], ropePrev[M + 1], knotT, knotPull, Vector3.zero)
		ropePrev[M + 1], rope[M + 1] = rope[M + 1], nextP
	end
	for i = 2, K do
		local s = (1 - math.cos(2 * math.pi * (i - 1) / K)) / 2
		local pull = (tuning.pullNear + (tuning.pullFar - tuning.pullNear) * s) * m2
		local open = flatten(ring[i] - centroid, up) * tuning.open * m2
		local nextP = integrate(ring[i], ringPrev[i], ringT[i], pull, open)
		ringPrev[i], ring[i] = ring[i], nextP
	end

	-- Constraints: rope and ring lengths, bend limits, the hand pin and the straight exit from the hand.
	local segRope = math.max(tuning.ropeLength * k, (knotT - grip).Magnitude) * tuning.slack / M
	local segRing = 2 * math.pi * tuning.ringRadius * k / K
	local function bendMin(limit: number): number
		return 2 * segRope * math.cos(math.rad(limit) / 2)
	end
	local minEnds, minMid = bendMin(tuning.bendEnds), bendMin(tuning.bendMid)
	rope[1] = grip
	for _ = 1, tuning.iterations do
		ring[1] = rope[M + 1]
		for i = 1, M do
			local d = rope[i + 1] - rope[i]
			local corr = d * (1 - segRope / math.max(d.Magnitude, 1e-6)) * 0.5
			if i == 1 then
				rope[2] -= corr * 2
			else
				rope[i] += corr
				rope[i + 1] -= corr
			end
		end
		-- A joint bends at most bendEnds (the two by the hand and the last) or bendMid degrees: a minimum distance
		-- between every other point. The hand end only pushes the far point.
		for i = 1, M - 1 do
			local minD = if i <= 2 or i == M - 1 then minEnds else minMid
			local d = rope[i + 2] - rope[i]
			local n = math.max(d.Magnitude, 1e-6)
			if n < minD then
				local corr = d * (1 - minD / n)
				if i == 1 then
					rope[3] -= corr
				else
					rope[i] += corr * 0.5
					rope[i + 2] -= corr * 0.5
				end
			end
		end
		rope[2] = grip + up * segRope
		for i = 1, K do
			local j = i % K + 1
			local d = ring[j] - ring[i]
			local corr = d * (1 - segRing / math.max(d.Magnitude, 1e-6)) * 0.5
			ring[i] += corr
			ring[j] -= corr
		end
		rope[M + 1] = ring[1]
		rope[1] = grip
	end
	ring[1] = rope[M + 1]
	ringPrev[1] = ropePrev[M + 1]

	-- Anything far from its pose (a teleport, a respawn) snaps back.
	local snap = tuning.snapDistance * k
	for i = 1, M + 1 do
		local target = ropeTarget(i)
		if (rope[i] - target).Magnitude > snap then
			rope[i], ropePrev[i] = target, target
		end
	end
	for i = 1, K do
		if (ring[i] - ringT[i]).Magnitude > snap then
			ring[i], ringPrev[i] = ringT[i], ringT[i]
		end
	end
	ring[1] = rope[M + 1]

	return {
		live = true,
		rope = rope,
		ropePrev = ropePrev,
		ring = ring,
		ringPrev = ringPrev,
		clock = clock,
		upright = upright,
		lastTip = tip,
		throwAt = throwAt,
		spin = spin,
		sidePrev = driver.side,
	}
end

return table.freeze(EmoteLassoFormulas)
