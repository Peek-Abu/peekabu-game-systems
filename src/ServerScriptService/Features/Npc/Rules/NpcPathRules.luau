--!strict
--[=[
	NpcPathRules: where an NPC heads, and when its path is stale. Pure; random rolls (0-1) are passed in.

	@class NpcPathRules
]=]

local NpcPathRules = {}
function NpcPathRules.supportedGoal(goal: Vector3, supportY: number?, rootHeight: number): Vector3
	return if supportY ~= nil then Vector3.new(goal.X, supportY + rootHeight, goal.Z) else goal
end

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

--[=[
	Whether to head straight at the goal rather than wait for the pathfinder: the goal is in clear line, no route is
	being followed (`routeIndex` outside 1..`routeCount`), and a path for it is still computing. The path is swapped
	in when it arrives; a finished computation that found none leaves the mover's own fallback in charge.
]=]
function NpcPathRules.headStraight(inLine: boolean, routeIndex: number, routeCount: number, computing: boolean): boolean
	local following = routeIndex >= 1 and routeIndex <= routeCount
	return inLine and computing and not following
end

function NpcPathRules.nextPatrolIndex(index: number, count: number): number
	return (index % count) + 1
end

-- A block behind the agent does not invalidate the remaining route.
function NpcPathRules.blockedAhead(blockedIndex: number, nextIndex: number, count: number): boolean
	return nextIndex >= 1 and nextIndex <= count and blockedIndex >= nextIndex and blockedIndex <= count
end

function NpcPathRules.stalled(
	previous: Vector3,
	position: Vector3,
	sampledAt: number,
	now: number,
	minimumProgress: number,
	timeout: number,
	hasGoal: boolean
): boolean
	local moved = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z).Magnitude
	return hasGoal and now - sampledAt >= timeout and moved < minimumProgress
end

local function flat(point: Vector3): Vector3
	return Vector3.new(point.X, 0, point.Z)
end

-- Adopt only the nearby portion reachable during ComputeAsync. A later parallel corridor must not win.
-- Jump segments remain mandatory: projection cannot silently skip their action.
function NpcPathRules.resumeIndex(
	points: { PathWaypoint },
	position: Vector3,
	travelBudget: number,
	corridor: number
): number?
	if #points < 2 then
		return if #points == 1 and (flat(position) - flat(points[1].Position)).Magnitude <= corridor then 1 else nil
	end
	local best: number? = nil
	local distance = corridor
	local travelled = 0
	for index = 2, #points do
		local start = flat(points[index - 1].Position)
		local delta = flat(points[index].Position) - start
		local length = delta.Magnitude
		local alpha = if length > 1e-3
			then math.clamp((flat(position) - start):Dot(delta) / (length * length), 0, 1)
			else 0
		local offset = (flat(position) - (start + delta * alpha)).Magnitude
		if travelled + length * alpha <= travelBudget and offset < distance then
			best = index
			distance = offset
		end
		travelled += length
		if travelled > travelBudget or points[index].Action == Enum.PathWaypointAction.Jump then
			break
		end
	end
	return best
end

-- Steering must advance even when a fast frame crosses the arrival disc. The lateral bound preserves corners.
function NpcPathRules.passedWaypoint(previous: Vector3, waypoint: Vector3, position: Vector3, radius: number): boolean
	local delta = flat(waypoint) - flat(previous)
	local offset = flat(position) - flat(waypoint)
	if offset.Magnitude <= radius then
		return true
	end
	return delta.Magnitude > 1e-3 and offset:Dot(delta.Unit) >= 0 and offset.Magnitude <= radius * 2
end

return NpcPathRules
