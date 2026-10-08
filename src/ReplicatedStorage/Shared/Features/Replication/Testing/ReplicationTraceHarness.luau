--!strict
--[=[
	Replication harness (spec 2026-09-22 §10), ported from the spike's A/B.

	A deterministic OWNER-TRUTH trace at an exact 60 Hz: the body a remote viewer should be seeing,
	sampled every frame. Both systems under test replay the SAME trace through the SAME simulated network,
	so every difference in the result is the replication system's.

	Built from Venture's real movement constants (Gravity 185, JumpPower 50.9, WalkSpeed 16, the slide's
	55 studs/s burst) and scripted to contain every hard case for a replicator:
	  idle · start/stop · a sharp 180° reversal · a 90° turn · running jumps · a slide burst · a zig-zag
	  strafe (a direction change every 0.25 s) · a wall-hop (an INSTANT +6 stud CFrame write plus a kick)
	  · a 90-stud ledge drop (terminal-ish fall, ~120 studs/s) with a hard landing · a respawn teleport.

	`teleportAt` lists the frames where the position jumps discontinuously (the wall-hop's CFrame write and
	the respawn), so metrics can tell a legitimate teleport from a replication pop.
]=]

local ReplicationTraceHarness = {}

export type TruthSample = {
	tMs: number,
	position: Vector3,
	velocity: Vector3,
	yaw: number,
	state: number,
	grounded: boolean,
	floorY: number, -- the floor under the body at this moment (for the viewer's ground query)
}

export type Trace = {
	samples: { TruthSample },
	teleportFrames: { [number]: boolean }, -- every discontinuity (wall-hop CFrame write, respawn)
	respawnFrames: { [number]: boolean }, -- server-initiated teleports only (these bump an epoch)
	name: string,
}

local GRAVITY = 185
local JUMP_VELOCITY = 50.9
local WALK = 16
local ACCEL = 140 -- studs/s² toward the intended velocity (a Humanoid reaches WalkSpeed in ~0.1 s)
local SLIDE_BURST = 55
local SLIDE_FRICTION = 60 -- studs/s² decay while sliding
local DT = 1 / 60

local STATE_RUNNING = Enum.HumanoidStateType.Running.Value
local STATE_JUMPING = Enum.HumanoidStateType.Jumping.Value
local STATE_FREEFALL = Enum.HumanoidStateType.Freefall.Value
local STATE_LANDED = Enum.HumanoidStateType.Landed.Value
local STATE_SLIDE = 30

type Segment = {
	duration: number,
	intent: Vector3?, -- horizontal unit direction (nil = stop)
	jumpAt: number?, -- seconds into the segment
	slideAt: number?,
	wallHopAt: number?,
	dropFloorBy: number?, -- the floor falls away at the segment start (a ledge)
	zigzag: boolean?,
	respawnTo: Vector3?,
}

local X, Z = Vector3.xAxis, Vector3.zAxis

local PARKOUR: { Segment } = {
	{ duration = 0.6 }, -- idle
	{ duration = 1.4, intent = -Z }, -- run
	{ duration = 1.0, intent = Z }, -- sharp 180° reversal
	{ duration = 1.0, intent = X }, -- 90° turn
	{ duration = 1.4, intent = X, jumpAt = 0.2 }, -- running jump
	{ duration = 1.2, intent = -Z, slideAt = 0.25 }, -- run into a slide burst
	{ duration = 2.0, intent = X, zigzag = true }, -- strafe zig-zag
	{ duration = 0.5 }, -- stop
	{ duration = 1.6, intent = -X, wallHopAt = 0.3 }, -- wall-hop (CFrame write + kick)
	{ duration = 3.0, intent = Z, dropFloorBy = 90 }, -- off a 90-stud ledge
	{ duration = 1.0, intent = -X, jumpAt = 0.1 }, -- jump after the landing
	{ duration = 0.6 },
	{ duration = 1.0, respawnTo = Vector3.new(40, 0, 40) }, -- respawn teleport
	{ duration = 1.5, intent = Z, jumpAt = 0.5 },
	{ duration = 0.6 },
}

local function yawOf(v: Vector3, fallback: number): number
	local h = Vector3.new(v.X, 0, v.Z)
	if h.Magnitude < 0.5 then
		return fallback
	end
	return math.atan2(-h.X, -h.Z)
end

--[=[
	The parkour trace, about 18 s at 60 Hz, starting at `origin`.
]=]
function ReplicationTraceHarness.parkour(origin: Vector3): Trace
	local samples: { TruthSample } = {}
	local teleports: { [number]: boolean } = {}
	local respawns: { [number]: boolean } = {}
	local floorY = origin.Y
	local position = origin
	local velocity = Vector3.zero
	local grounded = true
	local sliding = 0
	local yaw = 0
	local frame = 0
	local landedFor = 0
	for _, segment in PARKOUR do
		local frames = math.floor(segment.duration / DT + 0.5)
		if segment.dropFloorBy ~= nil then
			floorY -= segment.dropFloorBy
		end
		for f = 0, frames - 1 do
			local t = f * DT
			local teleported = false
			local respawned = false
			if f == 0 and segment.respawnTo ~= nil then
				position = origin + segment.respawnTo
				floorY = position.Y
				velocity = Vector3.zero
				grounded = true
				teleported = true
				respawned = true
			end
			-- intent
			local intent = segment.intent
			if intent ~= nil and segment.zigzag then
				local side = if math.floor(t / 0.25) % 2 == 0 then 1 else -1
				intent = (intent + Z * side).Unit
			end
			local wanted = if intent ~= nil then intent * WALK else Vector3.zero
			local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
			if sliding > 0 then
				sliding -= DT
				local speed = math.max(WALK, horizontal.Magnitude - SLIDE_FRICTION * DT)
				horizontal = if horizontal.Magnitude > 0 then horizontal.Unit * speed else horizontal
			elseif grounded then
				local delta = wanted - horizontal
				local step = ACCEL * DT
				horizontal = if delta.Magnitude <= step then wanted else horizontal + delta.Unit * step
			else
				-- airborne: weak air control
				local delta = wanted - horizontal
				local step = ACCEL * 0.25 * DT
				horizontal = if delta.Magnitude <= step then wanted else horizontal + delta.Unit * step
			end
			local vy = velocity.Y
			if segment.jumpAt ~= nil and math.abs(t - segment.jumpAt) < DT / 2 and grounded then
				vy = JUMP_VELOCITY
				grounded = false
			end
			if segment.slideAt ~= nil and math.abs(t - segment.slideAt) < DT / 2 and grounded then
				sliding = 0.6
				horizontal = (if horizontal.Magnitude > 0.1 then horizontal.Unit else -Z) * SLIDE_BURST
			end
			if segment.wallHopAt ~= nil and math.abs(t - segment.wallHopAt) < DT / 2 then
				-- The spike's F: a direct CFrame write, then a velocity kick off the wall.
				position += Vector3.new(0, 6, 0) + X * 1.5
				vy = 45
				horizontal = X * 30
				grounded = false
				teleported = true
			end
			if not grounded then
				vy -= GRAVITY * DT
			end
			velocity = Vector3.new(horizontal.X, vy, horizontal.Z)
			position += velocity * DT
			local wasGrounded = grounded
			if position.Y <= floorY then
				position = Vector3.new(position.X, floorY, position.Z)
				velocity = Vector3.new(velocity.X, 0, velocity.Z)
				grounded = true
				if not wasGrounded then
					landedFor = 0.12
				end
			elseif grounded and position.Y > floorY + 0.01 then
				grounded = false -- walked off the ledge
			end
			yaw = yawOf(velocity, yaw)
			local state = if not grounded
				then (if velocity.Y > 0 then STATE_JUMPING else STATE_FREEFALL)
				elseif sliding > 0 then STATE_SLIDE
				elseif landedFor > 0 then STATE_LANDED
				else STATE_RUNNING
			landedFor = math.max(0, landedFor - DT)
			frame += 1
			if teleported then
				teleports[frame] = true
			end
			if respawned then
				respawns[frame] = true
			end
			samples[frame] = {
				tMs = (frame - 1) * DT * 1000,
				position = position,
				velocity = velocity,
				yaw = yaw,
				state = state,
				grounded = grounded,
				floorY = floorY,
			}
		end
	end
	return { samples = samples, teleportFrames = teleports, respawnFrames = respawns, name = "parkour" }
end

--[=[
	Truth at an arbitrary time (linear between frames), for scoring a renderer's position against where the
	body really was at the moment it claims to be showing.
]=]
function ReplicationTraceHarness.at(trace: Trace, tMs: number): Vector3
	local samples = trace.samples
	local index = tMs / (DT * 1000) + 1
	local i = math.clamp(math.floor(index), 1, #samples)
	local j = math.min(i + 1, #samples)
	local s = math.clamp(index - i, 0, 1)
	return samples[i].position:Lerp(samples[j].position, s)
end

--[=[
	The viewer's stand-in for a downward raycast: the floor height under `position`, taken from the truth
	sample nearest to it horizontally. A real client raycasts the map it already has; this gives the harness
	the same knowledge without a map.
]=]
function ReplicationTraceHarness.groundBelow(trace: Trace, position: Vector3): number
	local best, bestDistance = trace.samples[1].floorY, math.huge
	for _, sample in trace.samples do
		local offset = sample.position - position
		local distance = offset.X * offset.X + offset.Z * offset.Z
		if distance < bestDistance and sample.floorY <= position.Y + 1 then
			best, bestDistance = sample.floorY, distance
		end
	end
	return best
end

ReplicationTraceHarness.FRAME_MS = DT * 1000

--[=[
	A session with idle time: `plan` is a list of steps, each either "P" (the parkour trace, continued from where
	the body stands) or a number of seconds standing still. Teleport and respawn frames are carried over.
]=]
function ReplicationTraceHarness.withIdle(base: Trace, plan: { number | "P" }): Trace
	local samples: { TruthSample } = {}
	local teleports: { [number]: boolean } = {}
	local respawns: { [number]: boolean } = {}
	local last: TruthSample? = nil
	for _, step in plan do
		if step == "P" then
			local offset = if last ~= nil then last.position - base.samples[1].position else Vector3.zero
			local start = #samples
			for i, s in base.samples do
				samples[start + i] = {
					tMs = 0,
					position = s.position + offset,
					velocity = s.velocity,
					yaw = s.yaw,
					state = s.state,
					grounded = s.grounded,
					floorY = s.floorY + offset.Y,
				}
			end
			for frame in base.teleportFrames do
				teleports[start + frame] = true
			end
			for frame in base.respawnFrames do
				respawns[start + frame] = true
			end
			last = samples[#samples]
		elseif typeof(step) == "number" then
			local at = last or base.samples[1]
			for _ = 1, math.floor(step * 60) do
				table.insert(samples, {
					tMs = 0,
					position = at.position,
					velocity = Vector3.zero,
					yaw = at.yaw,
					state = Enum.HumanoidStateType.Running.Value,
					grounded = true,
					floorY = at.floorY,
				})
			end
			last = samples[#samples]
		end
	end
	for i, s in samples do
		s.tMs = (i - 1) * DT * 1000
	end
	return { samples = samples, teleportFrames = teleports, respawnFrames = respawns, name = "idle mix" }
end

return ReplicationTraceHarness
