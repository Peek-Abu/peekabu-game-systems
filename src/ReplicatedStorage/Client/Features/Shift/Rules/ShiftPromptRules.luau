--!strict
-- Pure nearby prompt selection. Ids resolve ties; a one-stud margin prevents rapid target flicker. `aim` is how squarely
-- the camera looks at a prompt's part (to its nearest point); `distance` stays the server's reach measure, to the centre.
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
-- How far off straight up or down (studs, across) the nearest point may be and still count as over or under a part.
local OVERHEAD = 0.01
--[=[
	How squarely `look` (the camera's look, a unit vector) points from `from` (the player's root) at a prompt's part,
	the box `cframe` / `size`: the dot with the direction to the box's nearest point, not to its centre, so a big part
	(the 12 x 16 truck bed) is ahead as soon as any of it is, wherever its centre lies. Standing over, under or in the
	part (the nearest point straight down, up, or here) it surrounds the player: straight ahead, 1. A zero size measures
	to the point itself (an attachment's prompt).
]=]
function Rules.aim(cframe: CFrame, size: Vector3, from: Vector3, look: Vector3): number
	local localPoint = cframe:PointToObjectSpace(from)
	local half = size / 2
	local nearest = cframe:PointToWorldSpace(
		Vector3.new(
			math.clamp(localPoint.X, -half.X, half.X),
			math.clamp(localPoint.Y, -half.Y, half.Y),
			math.clamp(localPoint.Z, -half.Z, half.Z)
		)
	)
	local offset = nearest - from
	if Vector3.new(offset.X, 0, offset.Z).Magnitude <= OVERHEAD then
		return 1
	end
	return look:Dot(offset.Unit)
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
