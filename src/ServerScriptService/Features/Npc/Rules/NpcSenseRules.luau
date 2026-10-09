--!strict
--[=[
	NpcSenseRules: what an NPC can perceive. Pure; the line-of-sight raycast is the service's.

	@class NpcSenseRules
]=]

export type Candidate = { id: number, position: Vector3 }

local NpcSenseRules = {}

--[=[
	Within `range` and within the `angle`-degree cone around `look` (360 = all around).
]=]
function NpcSenseRules.inSight(origin: Vector3, look: Vector3, target: Vector3, range: number, angle: number): boolean
	local offset = target - origin
	local distance = offset.Magnitude
	if distance > range then
		return false
	end
	if distance < 1e-3 or angle >= 360 or look.Magnitude < 1e-3 then
		return true
	end
	local cosine = offset.Unit:Dot(look.Unit)
	return cosine >= math.cos(math.rad(angle / 2))
end

--[=[
	The closest candidate's id and distance, or nil.
]=]
function NpcSenseRules.nearest(origin: Vector3, candidates: { Candidate }): (number?, number)
	local bestId: number? = nil
	local bestDistance = math.huge
	for _, candidate in candidates do
		local distance = (candidate.position - origin).Magnitude
		if distance < bestDistance then
			bestId = candidate.id
			bestDistance = distance
		end
	end
	return bestId, bestDistance
end

--[=[
	Whether a target last seen at `lastSeenAt` is still remembered at `now`.
]=]
function NpcSenseRules.remembers(lastSeenAt: number?, now: number, loseSightTime: number): boolean
	return lastSeenAt ~= nil and now - lastSeenAt <= loseSightTime
end

return NpcSenseRules
