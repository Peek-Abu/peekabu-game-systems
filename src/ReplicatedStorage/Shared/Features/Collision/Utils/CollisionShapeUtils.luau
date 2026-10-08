--!strict
--[=[
	CollisionShapeUtils (R6 spec 2026-10-08 §4, §5): pure player-collision geometry. No Instances.

	- `capsule` turns the size table into three primitive parts (Roblox has no capsule primitive): a bottom
	  ball, an upright cylinder, a top ball, each with its offset from the root.
	- `restingOn` / `pushDirection` / `slideOffVelocity` are the slide-off rule (heads aren't standable).
	- `nextSolid` is the range band with its buffer.

	@class CollisionShapeUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)

export type PartSpec = { name: string, shape: Enum.PartType, size: Vector3, offset: CFrame }

local CollisionShapeUtils = {}

-- A Cylinder part's axis is X; this stands it up along Y.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local SOLID_SQUARED = CollisionConstants.SOLID_RANGE * CollisionConstants.SOLID_RANGE
local RELEASE_SQUARED = CollisionConstants.RELEASE_RANGE * CollisionConstants.RELEASE_RANGE
local REACH_SQUARED = (2 * CollisionConstants.RADIUS) * (2 * CollisionConstants.RADIUS)

--[=[
	The capsule's three parts, root-relative: bottom ball, middle cylinder, top ball.
	@param radius number
	@param bottom number -- root-relative Y of the capsule's bottom
	@param top number -- root-relative Y of the capsule's top
	@return { PartSpec }
]=]
function CollisionShapeUtils.capsule(radius: number, bottom: number, top: number): { PartSpec }
	local diameter = 2 * radius
	local low, high = bottom + radius, top - radius
	local ball = Vector3.new(diameter, diameter, diameter)
	return {
		{ name = "Bottom", shape = Enum.PartType.Ball, size = ball, offset = CFrame.new(0, low, 0) },
		{
			name = "Middle",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(high - low, diameter, diameter),
			offset = CFrame.new(0, (low + high) / 2, 0) * UPRIGHT,
		},
		{ name = "Top", shape = Enum.PartType.Ball, size = ball, offset = CFrame.new(0, high, 0) },
	}
end

--[=[
	Do my feet rest on their head? Inside two radii horizontally, my feet within ±REST_GAP of their head top,
	and not rising faster than REST_MAX_RISE.
	@param mine Vector3 -- my root position
	@param riseSpeed number -- my vertical velocity
	@param theirs Vector3 -- their root position
	@return boolean
]=]
function CollisionShapeUtils.restingOn(mine: Vector3, riseSpeed: number, theirs: Vector3): boolean
	local dx, dz = mine.X - theirs.X, mine.Z - theirs.Z
	if dx * dx + dz * dz >= REACH_SQUARED then
		return false
	end
	local gap = (mine.Y + CollisionConstants.BOTTOM) - (theirs.Y + CollisionConstants.TOP)
	return gap > -CollisionConstants.REST_GAP
		and gap < CollisionConstants.REST_GAP
		and riseSpeed <= CollisionConstants.REST_MAX_RISE
end

--[=[
	The horizontal unit direction to push me off them: away from their centre, or my horizontal facing when
	I'm within CENTRE_EPSILON of it (+X if I'm looking straight up or down).
	@param mine Vector3
	@param theirs Vector3
	@param look Vector3 -- my root's LookVector
	@return Vector3
]=]
function CollisionShapeUtils.pushDirection(mine: Vector3, theirs: Vector3, look: Vector3): Vector3
	local flat = Vector3.new(mine.X - theirs.X, 0, mine.Z - theirs.Z)
	if flat.Magnitude > CollisionConstants.CENTRE_EPSILON then
		return flat.Unit
	end
	local facing = Vector3.new(look.X, 0, look.Z)
	return if facing.Magnitude > 0 then facing.Unit else Vector3.xAxis
end

--[=[
	My velocity with its component along `direction` raised to SLIDE_OFF_SPEED, or nil when it already is.
	@param velocity Vector3
	@param direction Vector3 -- a horizontal unit vector
	@return Vector3?
]=]
function CollisionShapeUtils.slideOffVelocity(velocity: Vector3, direction: Vector3): Vector3?
	local along = velocity:Dot(direction)
	if along >= CollisionConstants.SLIDE_OFF_SPEED then
		return nil
	end
	return velocity + direction * (CollisionConstants.SLIDE_OFF_SPEED - along)
end

--[=[
	The range band: a blocker turns solid at SOLID_RANGE or closer and stays solid out to RELEASE_RANGE.
	@param solid boolean -- whether it is solid now
	@param distanceSquared number -- squared distance from my root to theirs
	@return boolean
]=]
function CollisionShapeUtils.nextSolid(solid: boolean, distanceSquared: number): boolean
	return distanceSquared <= (if solid then RELEASE_SQUARED else SOLID_SQUARED)
end

return CollisionShapeUtils
