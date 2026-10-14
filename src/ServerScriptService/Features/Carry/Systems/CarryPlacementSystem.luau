--!strict
--[=[
	CarryPlacementSystem: keeps world objects put down near a player inside the building.

	Anything placed at an offset from a player (a drop, a throw's start, a dust bag) is validated from a safe
	interior point, the character's root or a pile's centre: a ray from there to the target stops `margin` short
	of the first collidable wall (CarryFormulas.clampAlong), and the result must stand over a floor of the same
	structure as the origin's floor at about its height (CarryFormulas.isSupported), else it falls back halfway
	and then to the origin. A thrown object is watched in flight: a step that crossed a wall or floor is pulled
	back to the near side (CarryFormulas.pullBack), so it cannot tunnel out however it is moving.

	@class CarryPlacementSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CarryFormulas = require(ReplicatedStorage.Shared.Features.Carry.Utils.CarryFormulas)

export type Guard = {
	-- Checks the part's latest move; false once it no longer needs watching.
	step: () -> boolean,
}

local CarryPlacementSystem = {}

local function paramsFor(ignore: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	-- Query-only volumes (safe zones, triggers) are not walls or floors.
	params.RespectCanCollide = true
	return params
end

-- The Workspace child an instance belongs to (the building, the depot, the baseplate, Terrain).
local function structureOf(instance: Instance): Instance
	local current = instance
	while current.Parent ~= nil and current.Parent ~= Workspace do
		current = current.Parent
	end
	return current
end

local function floorAt(point: Vector3, params: RaycastParams): RaycastResult?
	return Workspace:Raycast(
		point + Vector3.new(0, CarryConstants.FLOOR_PROBE_LIFT, 0),
		Vector3.new(0, -CarryConstants.FLOOR_PROBE, 0),
		params
	)
end

--[=[
	The point nearest `target`, on the way from `origin`, that is clear of walls by `margin` and over the
	origin's own floor. `origin` must be a safe interior point (a character root, a pile's centre).
]=]
function CarryPlacementSystem.safePoint(origin: Vector3, target: Vector3, ignore: { Instance }, margin: number): Vector3
	local params = paramsFor(ignore)
	local move = target - origin
	local hitDistance: number? = nil
	if move.Magnitude > 1e-6 then
		local hit = Workspace:Raycast(origin, move.Unit * (move.Magnitude + margin), params)
		hitDistance = if hit ~= nil then hit.Distance else nil
	end
	local clamped = CarryFormulas.clampAlong(origin, target, hitDistance, margin)
	local originFloor = floorAt(origin, params)
	local originFloorY = if originFloor ~= nil then originFloor.Position.Y else nil
	local originStructure = if originFloor ~= nil then structureOf(originFloor.Instance) else nil
	for _, candidate in { clamped, origin:Lerp(clamped, 0.5) } do
		local floor = floorAt(candidate, params)
		local same = floor ~= nil and (originStructure == nil or structureOf(floor.Instance) == originStructure)
		if
			CarryFormulas.isSupported(
				originFloorY,
				if floor ~= nil then floor.Position.Y else nil,
				same,
				CarryConstants.FLOOR_STEP
			)
		then
			return candidate
		end
	end
	return origin
end

--[=[
	The floor point under `safePoint(origin, target, ignore, margin)`: where an object spawned near a player
	(a dust bag) stands. The origin's floor when that point has none; `origin` itself when neither does.
]=]
function CarryPlacementSystem.floorNear(origin: Vector3, target: Vector3, ignore: { Instance }, margin: number): CFrame
	local params = paramsFor(ignore)
	local point = CarryPlacementSystem.safePoint(origin, target, ignore, margin)
	local floor = floorAt(point, params) or floorAt(origin, params)
	return CFrame.new(if floor ~= nil then floor.Position else origin)
end

--[=[
	What placement rays look through when placing `target`: the object itself and every character.
]=]
function CarryPlacementSystem.ignoreFor(target: Instance): { Instance }
	local ignore: { Instance } = { target }
	for _, other in Players:GetPlayers() do
		if other.Character ~= nil then
			table.insert(ignore, other.Character)
		end
	end
	return ignore
end

--[=[
	How far a placed object's centre stays from a wall: its horizontal half-extent plus the wall margin.
]=]
function CarryPlacementSystem.marginFor(target: PVInstance): number
	local size = if target:IsA("Model")
		then target:GetExtentsSize()
		elseif target:IsA("BasePart") then target.Size
		else Vector3.zero
	return math.max(size.X, size.Z) / 2 + CarryConstants.WALL_MARGIN
end

--[=[
	Moves `target` (pivot at `desired`) to the nearest point on the way out from `origin` (a safe interior point,
	the carrier's root) that stays inside: never through a wall, always over the origin's own floor. Keeps
	`desired`'s rotation; leaves `target` alone when it is already there.
]=]
function CarryPlacementSystem.placeInside(origin: Vector3, target: PVInstance, desired: CFrame)
	local point = CarryPlacementSystem.safePoint(
		origin,
		desired.Position,
		CarryPlacementSystem.ignoreFor(target),
		CarryPlacementSystem.marginFor(target)
	)
	if (target:GetPivot().Position - point).Magnitude > 1e-3 then
		target:PivotTo(desired.Rotation + point)
	end
end

--[=[
	A guard for `part` in flight: each `step` raycasts its move since the last step and, when that move crossed a
	collidable wall or floor, puts it back `margin` short of it and removes its velocity into that surface. Done
	(false) once the part is gone, anchored or picked up again.
]=]
function CarryPlacementSystem.guard(part: BasePart, ignore: { Instance }, margin: number): Guard
	local filter = table.clone(ignore)
	table.insert(filter, part)
	local params = paramsFor(filter)
	local last = part.Position
	return {
		step = function()
			if part.Parent == nil or part.Anchored or part:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE) ~= nil then
				return false
			end
			local current = part.Position
			local move = current - last
			if move.Magnitude > 1e-4 then
				local hit = Workspace:Raycast(last, move, params)
				if hit ~= nil then
					part.CFrame = CFrame.new(CarryFormulas.pullBack(last, hit.Position, margin)) * part.CFrame.Rotation
					local velocity = part.AssemblyLinearVelocity
					local into = velocity:Dot(hit.Normal)
					if into < 0 then
						part.AssemblyLinearVelocity = velocity - hit.Normal * into
					end
				end
			end
			last = part.Position
			return true
		end,
	}
end

--[=[
	Runs `guard(part, ignore, margin)` every frame for up to `seconds`. Returns a stop function.
]=]
function CarryPlacementSystem.watch(part: BasePart, ignore: { Instance }, margin: number, seconds: number): () -> ()
	local guard = CarryPlacementSystem.guard(part, ignore, margin)
	local elapsed = 0
	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed > seconds or not guard.step() then
			stop()
		end
	end)
	return stop
end

return CarryPlacementSystem
