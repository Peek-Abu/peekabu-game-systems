--!strict
--[=[
	AbilityTreasureUtils: Spot It!'s pick: the closest treasure (a grimy valuable nobody has claimed, buried under a
	dust pile or not) to a point, by straight-line distance, anywhere. Pure.

	@class AbilityTreasureUtils
]=]

export type Candidate = { id: number, position: Vector3, grimy: boolean, claimed: boolean }

local AbilityTreasureUtils = {}

--[=[
	The id of the closest qualifying candidate to `origin` (a tie goes to the lower id), or nil.
]=]
function AbilityTreasureUtils.closest(origin: Vector3, candidates: { Candidate }): number?
	local bestId: number? = nil
	local bestDistance = math.huge
	for _, candidate in candidates do
		if candidate.grimy and not candidate.claimed then
			local distance = (candidate.position - origin).Magnitude
			local current = bestId
			if distance < bestDistance or (distance == bestDistance and current ~= nil and candidate.id < current) then
				bestId = candidate.id
				bestDistance = distance
			end
		end
	end
	return bestId
end

return AbilityTreasureUtils
