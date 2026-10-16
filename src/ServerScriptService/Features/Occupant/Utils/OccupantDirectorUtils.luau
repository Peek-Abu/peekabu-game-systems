--!strict
--[=[
	OccupantDirectorUtils: where the director sends him (docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-
	design.md §4). Like Alien: Isolation's director it knows roughly where the crew is, never exactly: `steerPoint` aims a
	spread of studs off a crew member in a rolled direction and takes the walkable point nearest that aim, but never one
	within `minDistance` of them. `farPoint` is where a breather takes him (the route point farthest from every crew
	member). Distances are flat (X/Z). Pure.

	@class OccupantDirectorUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

export type Member = { userId: number, position: Vector3 }

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local OccupantDirectorUtils = {}

--[=[
	The candidate nearest a point `spread` studs (rolled by `distanceRoll`) from `center` in the direction `angleRoll`
	(0..1 of a full turn, 0 = +X), skipping candidates within `minDistance` of `center`; nil when none qualifies.
]=]
function OccupantDirectorUtils.steerPoint(
	center: Vector3,
	candidates: { Vector3 },
	spread: OccupantConstants.Range,
	angleRoll: number,
	distanceRoll: number,
	minDistance: number
): Vector3?
	local angle = math.clamp(angleRoll, 0, 1) * 2 * math.pi
	local distance = spread.min + (spread.max - spread.min) * math.clamp(distanceRoll, 0, 1)
	local aim = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, candidate in candidates do
		local away = flat(candidate, aim)
		if flat(candidate, center) >= minDistance and away < bestDistance then
			best = candidate
			bestDistance = away
		end
	end
	return best
end

--[=[
	The route point whose nearest crew member is farthest away (the first point when there is no crew).
]=]
function OccupantDirectorUtils.farPoint(route: { Vector3 }, crew: { Vector3 }): Vector3?
	local best: Vector3? = nil
	local bestScore = -math.huge
	for _, point in route do
		local nearest = math.huge
		for _, member in crew do
			nearest = math.min(nearest, flat(point, member))
		end
		if nearest > bestScore then
			best = point
			bestScore = nearest
		end
	end
	return best
end

--[=[
	One of `count` (1..count) by `roll`; nil when count < 1.
]=]
function OccupantDirectorUtils.pick(count: number, roll: number): number?
	if count < 1 then
		return nil
	end
	return math.clamp(math.floor(math.clamp(roll, 0, 1) * count) + 1, 1, count)
end

--[=[
	The index of the route point nearest `position`.
]=]
function OccupantDirectorUtils.nearestIndex(route: { Vector3 }, position: Vector3): number?
	local best: number? = nil
	local bestDistance = math.huge
	for index, point in route do
		local distance = flat(point, position)
		if distance < bestDistance then
			best = index
			bestDistance = distance
		end
	end
	return best
end

return OccupantDirectorUtils
