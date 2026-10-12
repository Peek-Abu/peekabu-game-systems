--!strict
-- Pure nearby prompt selection. Ids resolve ties; a one-stud margin prevents rapid target flicker.
export type Candidate = { id: number, distance: number, dot: number, range: number, visible: boolean, enabled: boolean }
local Rules = {}
function Rules.choose(candidates: { Candidate }, current: number?): number?
	local best: number? = nil
	local bestScore = math.huge
	local currentScore = math.huge
	for _, candidate in candidates do
		if candidate.enabled and candidate.visible and candidate.distance <= candidate.range and candidate.dot >= 0 then
			local score = candidate.distance + (1 - math.clamp(candidate.dot, 0, 1)) * 2
			if candidate.id == current then
				currentScore = score
			end
			if score < bestScore or (score == bestScore and (best == nil or candidate.id < best)) then
				best = candidate.id
				bestScore = score
			end
		end
	end
	if current ~= nil and currentScore <= bestScore + 1 and currentScore < math.huge then
		return current
	end
	return best
end
return Rules
