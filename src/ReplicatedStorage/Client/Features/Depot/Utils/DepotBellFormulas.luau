--!strict
--[=[
	DepotBellFormulas: the shift bell's ring over time (launch VFX 2026-11-16, owner: "ringing bell in lobby vfx").
	A gold Gleam moment, tier 3 (game-vfx-design): two gold rings burst out of the bell's cup one after another, three
	pairs of gold "(( ))" sound marks pop up its sides on the swing's beats, a short warm glow, and (TUNING.word) a
	"DING!" that pops above it. Gold soap bubbles float up too (DepotBellVfxSystem; no sparkle stars).

	Each part's shape at `elapsed` seconds after the ring; `live` is false before its delay and after its end. Pure.

	@class DepotBellFormulas
]=]

export type Wave = { live: boolean, studs: number, transparency: number }
export type Marks = { live: boolean, studs: number, scale: number, lift: number, rise: number, transparency: number }
export type Word = { live: boolean, scale: number, rotation: number, rise: number, transparency: number }

local TUNING = table.freeze({
	-- The gold rings: each `delay` after the ring, from `waveStart` studs across, growing `grow` over waveSeconds,
	-- starting at transparency `alpha`.
	waves = table.freeze({
		table.freeze({ delay = 0, grow = 6.5, alpha = 0 }),
		table.freeze({ delay = 0.16, grow = 5, alpha = 0.3 }),
	}),
	waveStart = 1.2,
	waveSeconds = 0.7,
	-- The sound-mark pairs: each `delay` after the ring, `studs` wide, `lift` over the bell's cup.
	marks = table.freeze({
		table.freeze({ delay = 0, studs = 3.6, lift = 0.3 }),
		table.freeze({ delay = 0.2, studs = 4.2, lift = 0.75 }),
		table.freeze({ delay = 0.4, studs = 4.8, lift = 1.2 }),
	}),
	marksSeconds = 0.65,
	marksStart = 0.5,
	marksPop = 0.22,
	marksGrow = 0.15,
	marksRise = 1,
	marksHold = 0.55,
	overshoot = 1.9,
	-- The warm glow (a PointLight in the Gleam gold): its peak brightness and its whole time.
	glowBrightness = 3,
	glowSeconds = 0.4,
	glowRange = 12,
	-- The "DING!" over the bell (owner pick B on the VFX picks page; false: pick A, no word).
	word = true,
	wordText = "DING!",
	wordLift = 2.6,
	wordRise = 0.8,
	wordSeconds = 1.1,
	wordHold = 0.6,
	-- Gold soap bubbles floating up.
	bubbles = 8,
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

function DepotBellFormulas.marks(index: number, elapsed: number): Marks
	local pair = TUNING.marks[index]
	local t = (elapsed - pair.delay) / TUNING.marksSeconds
	local k = math.clamp(t, 0, 1)
	local pop = TUNING.marksPop
	return {
		live = t >= 0 and t <= 1,
		studs = pair.studs,
		scale = if k < pop
			then TUNING.marksStart + (1 - TUNING.marksStart) * backOut(k / pop)
			else 1 + TUNING.marksGrow * (k - pop) / (1 - pop),
		lift = pair.lift,
		rise = TUNING.marksRise * easeOutCubic(k),
		transparency = fadeAfter(k, TUNING.marksHold),
	}
end

function DepotBellFormulas.glow(elapsed: number): number
	if elapsed < 0 or elapsed > TUNING.glowSeconds then
		return 0
	end
	return TUNING.glowBrightness * math.sin(elapsed / TUNING.glowSeconds * math.pi)
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
	local longest = math.max(TUNING.wordSeconds, TUNING.glowSeconds)
	for _, wave in TUNING.waves do
		longest = math.max(longest, wave.delay + TUNING.waveSeconds)
	end
	for _, pair in TUNING.marks do
		longest = math.max(longest, pair.delay + TUNING.marksSeconds)
	end
	return longest
end

return DepotBellFormulas
