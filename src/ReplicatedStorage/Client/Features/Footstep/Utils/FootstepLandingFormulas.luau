--!strict
--[=[
	FootstepLandingFormulas: when a character's body meets the floor or leaves it, read from its root's vertical speed
	sampled each frame (works for every character a client sees: a remote character's Humanoid state does not
	replicate, its root's velocity does). An impact is a fall of at least `minSpeed` studs/s that loses most of that
	speed in one sample (a land, or a thrown body hitting the floor); a jump is a take-off from about standing to at
	least `minSpeed` upward. A land plays louder the faster the fall. Pure.

	@class FootstepLandingFormulas
]=]

-- An impact keeps at most this share of the downward speed it had the sample before.
local KEEP = 0.4
-- A take-off starts from below this share of the jump speed.
local FROM = 0.3

local FootstepLandingFormulas = {}

-- The land's volume scale: SOFTEST for a step down, 1 from a fall of FULL_SPEED studs/s (a full jump lands ~50).
FootstepLandingFormulas.SOFTEST = 0.55
FootstepLandingFormulas.FULL_SPEED = 50

--[=[
	Whether the body just hit something: `before` (the last sample's vertical speed) fell at `minSpeed` or faster and
	`now` kept at most KEEP of it.
]=]
function FootstepLandingFormulas.impact(before: number, now: number, minSpeed: number): boolean
	return before <= -minSpeed and now > before * KEEP
end

--[=[
	Whether the body just took off: from below FROM x `minSpeed` upward to `minSpeed` or more.
]=]
function FootstepLandingFormulas.jumped(before: number, now: number, minSpeed: number): boolean
	return before < minSpeed * FROM and now >= minSpeed
end

--[=[
	Which of `count` variants a roll (0-1) picks (1-based), never `last` again when there is another to pick.
]=]
function FootstepLandingFormulas.variant(roll: number, count: number, last: number): number
	local index = math.clamp(math.floor(math.clamp(roll, 0, 1) * count) + 1, 1, count)
	if count > 1 and index == last then
		index = index % count + 1
	end
	return index
end

--[=[
	The land's volume scale for a fall at `fallSpeed` studs/s (positive).
]=]
function FootstepLandingFormulas.landScale(fallSpeed: number): number
	local soft = FootstepLandingFormulas.SOFTEST
	local share = math.clamp(fallSpeed / FootstepLandingFormulas.FULL_SPEED, 0, 1)
	return soft + (1 - soft) * share
end

return FootstepLandingFormulas
