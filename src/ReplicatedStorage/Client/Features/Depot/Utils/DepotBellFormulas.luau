--!strict
--[=[
	DepotBellFormulas: the shift bell's ring over time (launch VFX 2026-11-16; owner pick C, "the one with the light and
	gold ring on ground"). A gold Gleam moment, tier 3 (game-vfx-design): two gold rings roll out across the hub floor
	from the bell post, one a beat after the other, gold soap bubbles float up (DepotBellVfxSystem; no sparkle stars)
	and a short warm glow lights the bell, while the bell itself swings (DepotSpotSystem). The glow never snaps (owner:
	"enable at 0 brightness and do a super quick tween to proper brightness! same with fade out!"): it rises from 0 over
	glowIn, holds, and eases back to 0 over glowOut.

	Each part's shape at `elapsed` seconds after the ring; `live` is false before its delay and after its end. Pure.

	@class DepotBellFormulas
]=]

export type Ring = { live: boolean, radius: number, transparency: number }

local TUNING = table.freeze({
	-- The floor rings: each `delay` after the ring, from `ringStart` studs round the post out by `radius` over
	-- ringSeconds, starting at transparency `alpha`; solid until ringHold of its time, then fading.
	rings = table.freeze({
		table.freeze({ delay = 0, radius = 9, alpha = 0.05 }),
		table.freeze({ delay = 0.18, radius = 6.5, alpha = 0.35 }),
	}),
	ringStart = 0.6,
	ringSeconds = 1,
	ringHold = 0.35,
	-- How far above the floor the ring lies (no z-fighting) and how far down from the bell's cup the floor is looked for.
	ringLift = 0.04,
	floorProbe = 12,
	-- The warm glow (a PointLight in the Gleam gold): its brightness, how long it takes to fade in from 0, to hold and
	-- to fade back to 0 (seconds), and its range.
	glowBrightness = 2.5,
	glowIn = 0.06,
	glowHold = 0.08,
	glowOut = 0.26,
	glowRange = 12,
	-- Gold soap bubbles floating up.
	bubbles = 6,
})

local DepotBellFormulas = {}

DepotBellFormulas.TUNING = TUNING

local function easeOutCubic(t: number): number
	return 1 - (1 - t) ^ 3
end

function DepotBellFormulas.ring(index: number, elapsed: number): Ring
	local ring = TUNING.rings[index]
	local t = (elapsed - ring.delay) / TUNING.ringSeconds
	local k = math.clamp(t, 0, 1)
	local hold = TUNING.ringHold
	local fade = if k <= hold then 0 else ((k - hold) / (1 - hold)) ^ 2
	return {
		live = t >= 0 and t <= 1,
		radius = TUNING.ringStart + ring.radius * easeOutCubic(k),
		transparency = ring.alpha + (1 - ring.alpha) * fade,
	}
end

-- The glow's whole time: in, hold and out.
function DepotBellFormulas.glowSeconds(): number
	return TUNING.glowIn + TUNING.glowHold + TUNING.glowOut
end

function DepotBellFormulas.glow(elapsed: number): number
	local peak = TUNING.glowBrightness
	if elapsed <= 0 or elapsed >= DepotBellFormulas.glowSeconds() then
		return 0
	end
	if elapsed < TUNING.glowIn then
		-- Quad out up from 0: quick, but never a snap.
		local t = elapsed / TUNING.glowIn
		return peak * (1 - (1 - t) ^ 2)
	end
	local out = elapsed - TUNING.glowIn - TUNING.glowHold
	if out <= 0 then
		return peak
	end
	-- Quad in down to 0.
	local t = out / TUNING.glowOut
	return peak * (1 - t * t)
end

-- Seconds from the ring until its last part is gone.
function DepotBellFormulas.duration(): number
	local longest = DepotBellFormulas.glowSeconds()
	for _, ring in TUNING.rings do
		longest = math.max(longest, ring.delay + TUNING.ringSeconds)
	end
	return longest
end

return DepotBellFormulas
