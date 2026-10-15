--!strict
--[=[
	CarrySwaySystem: a bag hanging from a carrier's hand swings from it (cosmetic, client-only, on every client).

	The server joins a hanging bag to the carrier's RightHand with a Motor6D at its handle, tagged
	CarryConstants.HANG_TAG (CarryServiceServer, AnimationCarrySystem.mount). Each step writes that joint's Transform
	so the bag hangs plumb under the handle whatever the hand's angle, swung off plumb by a damped pendulum
	(CarryFormulas.swayStep) that the handle's horizontal acceleration drives: it trails when the carrier sets off, sways
	with the walk's bob and swings on when she stops. The owner calls `step` in RunService.PreSimulation, after the
	frame's animation (and IK) pass. The server never writes Transform, so nothing authoritative moves.

	@class CarrySwaySystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CarryFormulas = require(ReplicatedStorage.Shared.Features.Carry.Utils.CarryFormulas)

type Swing = { tilt: Vector2, rate: Vector2, position: Vector3?, velocity: Vector3? }

export type CarrySwayState = { tracked: number }

export type CarrySwaySystem = {
	-- Starts swinging a hanging bag's joint; returns the release (which puts the joint back at rest).
	track: (motor: Motor6D) -> () -> (),
	step: (dt: number) -> (),
	getState: () -> CarrySwayState,
}

local CarrySwaySystem = {}

-- The Transform (in the joint's frame, at the handle) that turns the bag from where the hand holds it to hanging with
-- its bottom `tilt` off plumb (radians along world X and Z). `joint` is the joint's world frame, `c1` its frame on the bag.
local function transformFor(joint: CFrame, c1: CFrame, tilt: Vector2): CFrame
	local held = (joint * c1:Inverse()).UpVector
	local up = -Vector3.new(math.tan(tilt.X), -1, math.tan(tilt.Y)).Unit
	local axis = held:Cross(up)
	if axis.Magnitude < 1e-6 then
		return if held:Dot(up) > 0 then CFrame.identity else CFrame.fromAxisAngle(joint.RightVector, math.pi)
	end
	local turn = CFrame.fromAxisAngle(axis.Unit, math.atan2(axis.Magnitude, held:Dot(up)))
	return joint.Rotation:Inverse() * turn * joint.Rotation
end

function CarrySwaySystem.new(): CarrySwaySystem
	local swings: { [Motor6D]: Swing } = {}

	return {
		track = function(motor)
			local swing: Swing = { tilt = Vector2.zero, rate = Vector2.zero, position = nil, velocity = nil }
			swings[motor] = swing
			return function()
				if swings[motor] == swing then
					swings[motor] = nil
				end
				motor.Transform = CFrame.identity
			end
		end,

		step = function(dt)
			if dt <= 0 then
				return
			end
			for motor, swing in swings do
				local part0 = motor.Part0
				if part0 == nil or motor.Part1 == nil then
					continue
				end
				local joint = part0.CFrame * motor.C0
				local position = joint.Position
				local previous = swing.position
				local velocity = if previous ~= nil then (position - previous) / dt else Vector3.zero
				local before = swing.velocity
				local accel = if before ~= nil then (velocity - before) / dt else Vector3.zero
				swing.position, swing.velocity = position, velocity
				local push = Vector2.new(accel.X, accel.Z)
				if push.Magnitude > CarryConstants.SWAY_ACCEL_MAX then
					push = push.Unit * CarryConstants.SWAY_ACCEL_MAX
				end
				-- From the handle to the bag's middle.
				local length = math.max(motor.C1.Position.Magnitude, 0.5)
				swing.tilt, swing.rate =
					CarryFormulas.swayStep(swing.tilt, swing.rate, push, dt, length, CarryConstants.SWAY)
				motor.Transform = transformFor(joint, motor.C1, swing.tilt)
			end
		end,

		getState = function()
			local tracked = 0
			for _ in swings do
				tracked += 1
			end
			return { tracked = tracked }
		end,
	}
end

return CarrySwaySystem
