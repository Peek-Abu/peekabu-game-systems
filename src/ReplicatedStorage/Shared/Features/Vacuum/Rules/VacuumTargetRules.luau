--!strict
--[=[
	VacuumTargetRules: which pile a vacuumer is cleaning. Shared, so the client's pick and the server's re-check
	are one rule. Pure.

	A pile is in reach when it is on the vacuumer's floor (within `height` up or down) and
	- its rim is within `head` studs (flat) of the wand's floor head, whatever way the body or camera faces; or
	- the vacuumer stands on it (its rim within `underfoot` of the root, flat); or
	- its rim is within `range` of the root and it lies in a cone (`minDot`) around the body's facing.
	The camera never counts: where the character and the wand are decide it. Distances are to a pile's rim (a
	circle `radius` round its centre), so a big pile counts from its edge, not its middle.

	`pick` keeps the pile already being cleaned while it is in reach (no flapping between two piles, each
	switch is a channel request), else takes the one nearest the floor head (the root with no floor head).

	@class VacuumTargetRules
]=]

export type Pile = { position: Vector3, radius: number }
export type Reach = { head: number, underfoot: number, range: number, minDot: number, height: number }

local VacuumTargetRules = {}

-- How much wider the server's cone is than the client's per call of `widened`.
local DOT_SLACK = 0.3

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Flat distance from `from` to the pile's rim (negative inside it).
local function rim(from: Vector3, pile: Pile): number
	return flat(pile.position - from).Magnitude - pile.radius
end

--[=[
	Whether `pile` is in reach of a vacuumer whose root is at `root`, facing `facing`, with its floor head at
	`head` (nil: no floor head to measure from).
]=]
function VacuumTargetRules.reaches(root: Vector3, facing: Vector3, head: Vector3?, pile: Pile, reach: Reach): boolean
	if math.abs(pile.position.Y - root.Y) > reach.height then
		return false
	end
	if head ~= nil and rim(head, pile) <= reach.head then
		return true
	end
	local fromRoot = rim(root, pile)
	if fromRoot <= reach.underfoot then
		return true
	end
	if fromRoot > reach.range then
		return false
	end
	local toward = flat(pile.position - root)
	local forward = flat(facing)
	if toward.Magnitude < 1e-6 or forward.Magnitude < 1e-6 then
		return true
	end
	return toward.Unit:Dot(forward.Unit) >= reach.minDot
end

--[=[
	The index of the pile to clean among `piles`: `current` while it is in reach, else the in-reach pile nearest
	the floor head (the root when `head` is nil); nil when none is in reach.
]=]
function VacuumTargetRules.pick(
	root: Vector3,
	facing: Vector3,
	head: Vector3?,
	piles: { Pile },
	reach: Reach,
	current: number?
): number?
	if current ~= nil then
		local held = piles[current]
		if held ~= nil and VacuumTargetRules.reaches(root, facing, head, held, reach) then
			return current
		end
	end
	local from = head or root
	local best: number? = nil
	local bestDistance = math.huge
	for index, pile in piles do
		if VacuumTargetRules.reaches(root, facing, head, pile, reach) then
			local distance = rim(from, pile)
			if distance < bestDistance then
				best = index
				bestDistance = distance
			end
		end
	end
	return best
end

--[=[
	A pile's radius: half its widest flat side as spawned (`baseSize`, its PileBaseSize attribute), so a pile
	shrinking while it is vacuumed does not slip out of reach; its current `size` when it has none.
]=]
function VacuumTargetRules.radius(size: Vector3, baseSize: unknown): number
	local full = if typeof(baseSize) == "Vector3" then baseSize else size
	return math.max(full.X, full.Z) / 2
end

--[=[
	`reach` with `slack` more studs on every distance and a wider cone: the server's re-check, which sees the
	vacuumer a moment later than the client that picked the pile.
]=]
function VacuumTargetRules.widened(reach: Reach, slack: number): Reach
	return {
		head = reach.head + slack,
		underfoot = reach.underfoot + slack,
		range = reach.range + slack,
		minDot = math.max(-1, reach.minDot - DOT_SLACK),
		height = reach.height,
	}
end

return table.freeze(VacuumTargetRules)
