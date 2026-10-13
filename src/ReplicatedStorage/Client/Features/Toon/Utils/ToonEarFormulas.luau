--!strict
--[=[
	ToonEarFormulas: the ear-spring maths (ToonEarSystem drives the joints with it).

	Each ear has two damped springs: pitch (lean back, positive tips the ear toward +Z, the back of a
	character facing -Z) and outward (swing away from the head's centre line). Targets come from how the
	root moved this frame, measured in the root's own frame so the same numbers work for the local
	character and for replicated ones (whose velocity properties are not reliable on this client):

	- forward speed leans both ears back;
	- turning swings both ears outward, sideways speed drags them against the motion;
	- rising droops them outward, falling presses them in, and a sharp landing kicks the outward spring;
	- a slow sway keeps them alive at rest.

	Everything is clamped to EAR_MAX_ANGLE: the ears are rigid one-piece meshes.

	@class ToonEarFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)

export type Motion = {
	-- Studs/s along the root's look direction.
	forward: number,
	-- Studs/s along the root's right vector.
	lateral: number,
	-- Studs/s, world up.
	vertical: number,
	-- Rad/s about world up (positive turns left).
	yawRate: number,
}

local MAX = ToonConstants.EAR_MAX_ANGLE

local ToonEarFormulas = {}

local function clampAngle(angle: number): number
	return math.clamp(angle, -MAX, MAX)
end

--[=[
	Advances one damped spring by dt (semi-implicit Euler, in fixed substeps; a hitch longer than
	EAR_MAX_DT is only integrated that far, so the ears never explode after a stall).
	@return (position, velocity)
]=]
function ToonEarFormulas.step(x: number, v: number, target: number, dt: number): (number, number)
	if dt <= 0 then
		return x, v
	end
	local remaining = math.min(dt, ToonConstants.EAR_MAX_DT)
	while remaining > 1e-9 do
		local h = math.min(remaining, ToonConstants.EAR_SUBSTEP)
		local accel = ToonConstants.EAR_STIFFNESS * (target - x) - ToonConstants.EAR_DAMPING * v
		v += accel * h
		x += v * h
		remaining -= h
	end
	return x, v
end

--[=[
	@param side -1 for the left ear, 1 for the right.
	@param t Seconds (any running clock).
	@param phase Per-character sway offset (radians).
	@return (pitch, outward) target angles in radians, clamped.
]=]
function ToonEarFormulas.targets(motion: Motion, side: number, t: number, phase: number): (number, number)
	local swayAngle = t * ToonConstants.EAR_SWAY_RATE + phase
	local amplitude = ToonConstants.EAR_SWAY_AMPLITUDE
	local pitch = math.max(motion.forward, 0) * ToonConstants.EAR_PITCH_PER_SPEED
		+ amplitude * 0.5 * math.sin(swayAngle * 0.7)
	local outward = math.abs(motion.yawRate) * ToonConstants.EAR_OUT_PER_YAW
		- side * motion.lateral * ToonConstants.EAR_OUT_PER_LATERAL
		+ (if motion.vertical > 0
			then motion.vertical * ToonConstants.EAR_OUT_PER_RISE
			else motion.vertical * ToonConstants.EAR_IN_PER_FALL)
		+ amplitude * math.sin(swayAngle + (side + 1) * 0.9)
	return clampAngle(pitch), clampAngle(outward)
end

--[=[
	The outward spring velocity (rad/s) a landing adds: a sharp upward change in vertical speed
	(a fall stopping) beyond EAR_LANDING_THRESHOLD. Zero for anything else.
]=]
function ToonEarFormulas.landingKick(previousVertical: number, vertical: number): number
	local change = vertical - previousVertical
	if previousVertical >= 0 or change < ToonConstants.EAR_LANDING_THRESHOLD then
		return 0
	end
	return math.min(change * ToonConstants.EAR_LANDING_KICK, ToonConstants.EAR_LANDING_KICK_MAX)
end

--[=[
	How the root moved from `from` to `to` over dt, in the root's frame (`to`).
]=]
function ToonEarFormulas.motion(from: CFrame, to: CFrame, dt: number): Motion
	if dt <= 0 then
		return { forward = 0, lateral = 0, vertical = 0, yawRate = 0 }
	end
	local velocity = (to.Position - from.Position) / dt
	local look = from.Rotation:ToObjectSpace(to.Rotation).LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	return {
		forward = velocity:Dot(to.LookVector),
		lateral = velocity:Dot(to.RightVector),
		vertical = velocity.Y,
		yawRate = yaw / dt,
	}
end

--[=[
	The ear joint's Transform: pitch about X, outward about Z (mirrored per side), clamped.
]=]
function ToonEarFormulas.transform(pitch: number, outward: number, side: number): CFrame
	return CFrame.Angles(clampAngle(pitch), 0, -side * clampAngle(outward))
end

return ToonEarFormulas
