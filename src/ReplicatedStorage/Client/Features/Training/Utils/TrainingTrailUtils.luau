--!strict
--[=[
	TrainingTrailUtils: the training guide's floor-trail maths (TrainingTrailSystem draws it). A path's points become
	straight legs (points closer than a minimum dropped, straight runs merged), the first legs trimmed so the trail
	starts a little ahead of the player's feet; the marker arrow's bob; and when to ask for a new path.

	@class TrainingTrailUtils
]=]

export type Leg = { from: Vector3, to: Vector3 }

-- Two directions closer than this (dot of their units) count as one straight run.
local STRAIGHT = 0.995

local TrainingTrailUtils = {}

--[=[
	The straight legs through `points`, in order: a point closer than `minLength` to the last kept one is dropped,
	and a point on the straight line through its neighbours merges their legs.
]=]
function TrainingTrailUtils.segments(points: { Vector3 }, minLength: number): { Leg }
	local kept: { Vector3 } = {}
	for _, point in points do
		local last: Vector3? = kept[#kept]
		if not last or (point - last).Magnitude >= minLength then
			table.insert(kept, point)
		end
	end
	local corners: { Vector3 } = {}
	for index, point in kept do
		local before: Vector3? = kept[index - 1]
		local after: Vector3? = kept[index + 1]
		local straight = if before and after then (point - before).Unit:Dot((after - point).Unit) >= STRAIGHT else false
		if not straight then
			table.insert(corners, point)
		end
	end
	local legs: { Leg } = {}
	for index = 2, #corners do
		table.insert(legs, { from = corners[index - 1], to = corners[index] })
	end
	return legs
end

--[=[
	`legs` with the first `distance` studs cut off the start (whole legs shorter than what is left to cut dropped).
]=]
function TrainingTrailUtils.trimStart(legs: { Leg }, distance: number): { Leg }
	local result: { Leg } = {}
	local left = distance
	for _, leg in legs do
		local length = (leg.to - leg.from).Magnitude
		if left <= 0 then
			table.insert(result, leg)
		elseif length > left then
			local from = leg.from + (leg.to - leg.from).Unit * left
			table.insert(result, { from = from, to = leg.to })
			left = 0
		else
			left -= length
		end
	end
	return result
end

--[=[
	The marker arrow's lift at time `t`: rising and falling between 0 and `height`, `speed` radians a second.
]=]
function TrainingTrailUtils.bob(t: number, height: number, speed: number): number
	return height * (math.sin(t * speed) + 1) / 2
end

--[=[
	Whether to ask for a new path: never asked, the player moved `distance` studs since, or `seconds` went by.
]=]
function TrainingTrailUtils.repath(
	lastFrom: Vector3?,
	from: Vector3,
	lastAt: number,
	now: number,
	distance: number,
	seconds: number
): boolean
	if not lastFrom then
		return true
	end
	return (from - lastFrom).Magnitude >= distance or now - lastAt >= seconds
end

return TrainingTrailUtils
