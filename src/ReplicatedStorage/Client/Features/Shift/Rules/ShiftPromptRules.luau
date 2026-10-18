--!strict
-- Pure nearby prompt selection. Ids resolve ties; a one-stud margin prevents rapid target flicker.
-- `sight` judges one part the sight ray from the camera to a prompt hit, by the camera's own rule
-- (CameraOccluderRules): what stops the third-person camera also hides a prompt, and what the camera looks through
-- (invisible non-colliding volumes such as the truck's SafeZone, see-through or non-colliding art) does not.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraOccluderRules = require(ReplicatedStorage.Client.Features.Camera.Rules.CameraOccluderRules)

export type Candidate = { id: number, distance: number, dot: number, range: number, visible: boolean, enabled: boolean }
-- "target": the ray reached the prompt's object; "past": look on through this part; "blocked": the prompt is hidden.
export type Sight = "target" | "past" | "blocked"
local Rules = {}
--[=[
	What the sight ray toward `target` makes of hitting `part`. `ownRoot` is the local player's root part: anything in
	its assembly (what they carry, welded to them, even a flagged furniture proxy) is looked past.
]=]
function Rules.sight(part: BasePart, target: Instance, ownRoot: BasePart?): Sight
	if part == target or part:IsDescendantOf(target) then
		return "target"
	end
	local ownAssembly: BasePart? = if ownRoot ~= nil then ownRoot.AssemblyRootPart else nil
	if ownAssembly ~= nil and part.AssemblyRootPart == ownAssembly then
		return "past"
	end
	return if CameraOccluderRules.blocks(part) then "blocked" else "past"
end
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
