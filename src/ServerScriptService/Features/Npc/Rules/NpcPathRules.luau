--!strict
--[=[
	NpcPathRules: where an NPC heads, and when its path is stale. Pure; random rolls (0-1) are passed in.

	@class NpcPathRules
]=]

local NpcPathRules = {}

--[=[
	A point in the disc of `radius` around `home` (uniform over the area), at home's height.
]=]
function NpcPathRules.wanderGoal(home: Vector3, radius: number, angleRoll: number, distanceRoll: number): Vector3
	local angle = angleRoll * math.pi * 2
	local distance = radius * math.sqrt(math.clamp(distanceRoll, 0, 1))
	return home + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

--[=[
	A point `distance` away from `threat`, straight away from it on the horizontal plane.
]=]
function NpcPathRules.fleeGoal(position: Vector3, threat: Vector3, distance: number): Vector3
	local away = Vector3.new(position.X - threat.X, 0, position.Z - threat.Z)
	local direction = if away.Magnitude > 1e-3 then away.Unit else Vector3.new(1, 0, 0)
	return position + direction * distance
end

--[=[
	Whether to compute a new path: none yet, the goal moved more than `threshold`, or the path is older
	than `maxAge`.
]=]
function NpcPathRules.shouldRepath(
	currentGoal: Vector3?,
	newGoal: Vector3,
	computedAt: number?,
	now: number,
	threshold: number,
	maxAge: number
): boolean
	if currentGoal == nil or computedAt == nil then
		return true
	end
	return (newGoal - currentGoal).Magnitude > threshold or now - computedAt > maxAge
end

function NpcPathRules.nextPatrolIndex(index: number, count: number): number
	return (index % count) + 1
end

return NpcPathRules
