--!strict
--[=[
	AnimationCarryGrabFormulas: the timeline of the cosmetic pickup (AnimationCarryGrabSystem). The server has already
	welded the cargo into the carrier's hands; each client replays the moment it took: the cargo shown where it lay
	while the arms (and a waist bend) reach down to it for REACH_SECONDS, then lifted along a short scoop into the
	hold over LIFT_SECONDS. Pure.

	@class AnimationCarryGrabFormulas
]=]

local AnimationCarryGrabFormulas = {
	-- The arms reach the cargo where it lies.
	REACH_SECONDS = 0.12,
	-- The cargo rises into the hold.
	LIFT_SECONDS = 0.2,
	-- Studs the lift bows upward at its middle.
	ARC = 0.35,
	-- Farther than this (studs) between where the cargo lay and the hold, the grab is skipped (a pickup prompt is
	-- always close; anything else is a teleport or a stale origin).
	MAX_DISTANCE = 14,
	-- Closer than this, the cargo was effectively in the hands already.
	MIN_DISTANCE = 0.2,
}

-- Smoothstep: eases in and out.
local function ease(u: number): number
	return u * u * (3 - 2 * u)
end

-- Whether the grab plays for cargo that lay at `from` and is held at `to`.
function AnimationCarryGrabFormulas.plays(from: CFrame, to: CFrame): boolean
	local distance = (from.Position - to.Position).Magnitude
	return distance >= AnimationCarryGrabFormulas.MIN_DISTANCE and distance <= AnimationCarryGrabFormulas.MAX_DISTANCE
end

-- Where the cargo is shown `elapsed` seconds into the grab (`to` is the live hold, so it follows a moving carrier).
function AnimationCarryGrabFormulas.pose(from: CFrame, to: CFrame, elapsed: number): CFrame
	local lift = elapsed - AnimationCarryGrabFormulas.REACH_SECONDS
	if lift < 0 then
		return from
	end
	if lift >= AnimationCarryGrabFormulas.LIFT_SECONDS then
		return to
	end
	local u = lift / AnimationCarryGrabFormulas.LIFT_SECONDS
	local k = ease(u)
	local bow = Vector3.yAxis * (AnimationCarryGrabFormulas.ARC * 4 * u * (1 - u))
	local blended = from:Lerp(to, k)
	return blended + bow
end

-- Whether the grab is over `elapsed` seconds in.
function AnimationCarryGrabFormulas.finished(elapsed: number): boolean
	return elapsed >= AnimationCarryGrabFormulas.REACH_SECONDS + AnimationCarryGrabFormulas.LIFT_SECONDS
end

return AnimationCarryGrabFormulas
