--!strict
--[=[
	DepotBellFormulas: the shift bell's ring over time (launch VFX 2026-11-16; owner pick B: "the bigger DING with one
	ring and bubbles"). A gold Gleam moment, tier 3 (game-vfx-design): one gold ring bursts out of the bell's cup, a
	big "DING!" pops above it, gold soap bubbles float up (DepotBellVfxSystem; no sparkle stars) and a short warm glow
	lights the bell, while the bell itself swings (DepotSpotSystem). The glow never snaps (owner: "enable at 0
	brightness and do a super quick tween to proper brightness! same with fade out!"): it rises from 0 over glowIn,
	holds, and eases back to 0 over glowOut.

	Each part's shape at `elapsed` seconds after the ring; `live` is false before its delay and after its end. Pure.

	@class DepotBellFormulas
]=]

export type Wave = { live: boolean, studs: number, transparency: number }
export type Word = { live: boolean, scale: number, rotation: number, rise: number, transparency: number }

local TUNING = table.freeze({
	-- The gold ring: `delay` after the ring, from `waveStart` studs across, growing `grow` over waveSeconds, starting
	-- at transparency `alpha`.
	waves = table.freeze({
		table.freeze({ delay = 0, grow = 5, alpha = 0 }),
	}),
	waveStart = 1.2,
	waveSeconds = 0.7,
	overshoot = 1.9,
	-- The warm glow (a PointLight in the Gleam gold): its brightness, how long it takes to fade in from 0, to hold and
	-- to fade back to 0 (seconds), and its range.
	glowBrightness = 3,
	glowIn = 0.06,
	glowHold = 0.08,
	glowOut = 0.26,
	glowRange = 12,
	-- The "DING!" over the bell's cup: `wordStuds` wide (its height is 0.4 of that), `wordLift` over the cup.
	word = true,
	wordText = "DING!",
	wordStuds = 7,
	wordLift = 2.2,
	wordRise = 0.8,
	wordSeconds = 1.1,
	wordHold = 0.6,
	-- Gold soap bubbles floating up.
	bubbles = 6,
})

local DepotBellFormulas = {}

DepotBellFormulas.TUNING = TUNING

local function easeOutCubic(t: number): number
	return 1 - (1 - t) ^ 3
end

local function backOut(t: number): number
	local c = TUNING.overshoot
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

local function fadeAfter(t: number, hold: number): number
	return if t <= hold then 0 else ((t - hold) / (1 - hold)) ^ 2
end

function DepotBellFormulas.wave(index: number, elapsed: number): Wave
	local wave = TUNING.waves[index]
	local t = (elapsed - wave.delay) / TUNING.waveSeconds
	local k = math.clamp(t, 0, 1)
	return {
		live = t >= 0 and t <= 1,
		studs = TUNING.waveStart + wave.grow * easeOutCubic(k),
		transparency = wave.alpha + (1 - wave.alpha) * k ^ 1.6,
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

function DepotBellFormulas.word(elapsed: number): Word
	local t = elapsed / TUNING.wordSeconds
	local k = math.clamp(t, 0, 1)
	local pop = 0.18
	return {
		live = t >= 0 and t <= 1,
		scale = if k < pop then backOut(k / pop) else 1,
		rotation = -6 + 4 * math.sin(k * 9) * (1 - k),
		rise = TUNING.wordRise * easeOutCubic(k),
		transparency = fadeAfter(k, TUNING.wordHold),
	}
end

-- Seconds from the ring until its last part is gone.
function DepotBellFormulas.duration(): number
	local longest = math.max(TUNING.wordSeconds, DepotBellFormulas.glowSeconds())
	for _, wave in TUNING.waves do
		longest = math.max(longest, wave.delay + TUNING.waveSeconds)
	end
	return longest
end

return DepotBellFormulas
