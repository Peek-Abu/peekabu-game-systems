--!strict
--[=[
	UIToonConstants: Cleanup Crew's V1 "Gloom & Gleam" kit (picked 2026-10-17; `characters/ui/kits/v2/V1-gloom-gleam`):
	the palette (each colour with its hi and lo shade), the two fonts, the depth-stack geometry every panel, button,
	pill and slot is built from, the selected ring (V2's lilac, adopted into V1), the number gradients, and the motion
	timings. Every Toon component reads only this. Values are at the 1920x1080 design (the HUD scales them with
	PaperHudFrame).

	Static data only (frozen tables), so there is nothing a spec could assert.

	@class UIToonConstants
]=]

export type Shade = { base: Color3, hi: Color3, lo: Color3 }
export type Hue = "grape" | "gold" | "mint" | "coral" | "cream" | "night" | "sky" | "lilac" | "steel"
export type Meaning = "gold" | "mint" | "coral" | "grape" | "white"

local function shade(base: string, hi: string, lo: string): Shade
	return table.freeze({ base = Color3.fromHex(base), hi = Color3.fromHex(hi), lo = Color3.fromHex(lo) })
end

-- Every outline, hard drop and text stroke (never pure black).
local INK = Color3.fromHex("1E0F3A")

local HUE: { [Hue]: Shade } = table.freeze({
	-- Headers, the Gloom, primary chrome.
	grape = shade("7B3FF2", "B48BFF", "5523C2"),
	-- Gleam, rewards, money, sparkles.
	gold = shade("FFC93A", "FFF2A8", "E08A0C"),
	-- GO / confirm / XP.
	mint = shade("33E8A9", "BFFFE7", "0FA06F"),
	-- Danger, the Manager, close.
	coral = shade("FF4F6E", "FFAABA", "C2264A"),
	-- Light panel bodies (with the sparkle pattern).
	cream = shade("FFF7E8", "FFFFFF", "E9D2AE"),
	-- Dark panels and tracks.
	night = shade("2B1856", "4D3290", "170B33"),
	-- Info, cool accents.
	sky = shade("5CC8FF", "C4ECFF", "2A8FD0"),
	-- Pippa's lilac: quiet chrome (the Settings tile, secondary dark pills).
	lilac = shade("B7A4EC", "EDE6FF", "8A73C9"),
	-- Disabled: the stack desaturated.
	steel = shade("B9B4C6", "E6E3EE", "8A8499"),
})

local COLOR = table.freeze({
	ink = INK,
	-- The meter tracks.
	track = Color3.fromHex("26124C"),
	-- V2's Pippa-lilac selected ring and glow.
	selected = Color3.fromHex("B79CFF"),
	white = Color3.new(1, 1, 1),
	-- The goo's own colours (the meter fill and the wipe's dirt).
	gooHi = Color3.fromHex("C59BFF"),
	gooBase = Color3.fromHex("7B3FF2"),
	gooLo = Color3.fromHex("4A1CA8"),
	dirt = Color3.fromHex("2A0E5C"),
	-- The red screen-edge vignette in a shift.
	danger = Color3.fromHex("FF2E55"),
})

-- A number's gradient fill, top to bottom, by what it means: gold = Gleam, mint = gain, coral = time/danger,
-- grape = Gloom, white = plain labels.
local NUMBER: { [Meaning]: { Color3 } } = table.freeze({
	gold = table.freeze({
		Color3.fromHex("FFFBE0"),
		Color3.fromHex("FFE066"),
		Color3.fromHex("FFB21A"),
		Color3.fromHex("E8730C"),
	}),
	mint = table.freeze({
		Color3.fromHex("F2FFF9"),
		Color3.fromHex("8BF5CF"),
		Color3.fromHex("33E8A9"),
		Color3.fromHex("0FA06F"),
	}),
	coral = table.freeze({
		Color3.fromHex("FFF0F3"),
		Color3.fromHex("FF9AAE"),
		Color3.fromHex("FF4F6E"),
		Color3.fromHex("C2264A"),
	}),
	grape = table.freeze({
		Color3.fromHex("F3ECFF"),
		Color3.fromHex("C9A8FF"),
		Color3.fromHex("9A66FF"),
		Color3.fromHex("5523C2"),
	}),
	white = table.freeze({
		Color3.new(1, 1, 1),
		Color3.new(1, 1, 1),
		Color3.fromHex("F4EEFF"),
		Color3.fromHex("E2D6FF"),
	}),
})

local function face(font: Enum.Font, weight: Enum.FontWeight): Font
	return Font.new(Font.fromEnum(font).Family, weight)
end

local FONT = table.freeze({
	-- Display, numbers, buttons: white fill, ink stroke, hard drop.
	display = face(Enum.Font.LuckiestGuy, Enum.FontWeight.Regular),
	-- Body copy: ink on light, white on dark.
	body = face(Enum.Font.FredokaOne, Enum.FontWeight.Regular),
})

-- The depth stack (depth-stack.md), in design px.
local DEPTH = table.freeze({
	panelRadius = 26,
	buttonRadius = 24,
	pillRadius = 999,
	outline = 5,
	-- The hard ink drop under the element.
	drop = 7,
	-- The darker band of the body's own hue along the bottom.
	lip = 9,
	-- The gloss band covers the top 44% and has a hard lower edge.
	gloss = 0.44,
	-- The inner light rim just inside the outline.
	rim = 2,
	rimTransparency = 0.45,
	-- The pattern tile's transparency over a fill (6-12% visible).
	patternTransparency = 0.9,
	-- Text: the stroke and the drop for display text, as a fraction of the text size (clamped in the view model).
	textStroke = 0.12,
	textDrop = 0.08,
})

local MOTION = table.freeze({
	-- Hover: lift and scale. Press: drop by the drop height and shrink.
	hoverLift = 4,
	hoverScale = 1.04,
	pressScale = 0.96,
	hoverSeconds = 0.14,
	pressSeconds = 0.07,
	-- Selected: lift, scale and the lilac ring.
	selectedLift = 6,
	selectedScale = 1.03,
	-- Siblings of a selected item recede.
	recedeScale = 0.97,
	-- Pop-in: 0.6 -> 1.08 -> 1 over 0.25 s.
	popFrom = 0.6,
	popOvershoot = 1.08,
	popSeconds = 0.25,
	-- The squeegee wipe across a panel that opens.
	wipeSeconds = 0.35,
	wipeDelay = 0.12,
	-- Sparkles twinkle on a stagger.
	sparklePeriod = 1.6,
})

-- Roblox's own controls, kept clear (design px): the top-left menu/chat buttons, the phone thumbstick (bottom-left)
-- and Jump (bottom-right).
local SAFE = table.freeze({
	desktop = table.freeze({ left = 24, right = 24, top = 72, bottom = 24 }),
	phone = table.freeze({ left = 48, right = 48, top = 8, bottom = 12 }),
})

-- A hue's three shades (a function: the HUE table is keyed by the Hue union, so it is read through a Hue value).
local function shadeOf(hue: Hue): Shade
	return HUE[hue]
end

local UIToonConstants = {
	HUE = HUE,
	shade = shadeOf,
	COLOR = COLOR,
	NUMBER = NUMBER,
	FONT = FONT,
	DEPTH = DEPTH,
	MOTION = MOTION,
	SAFE = SAFE,
	-- The goo pieces' size in design px (the images are 2x): one tile / one end of each kind.
	GOO = table.freeze({
		tile = 128,
		capHeight = 56,
		poolHeight = 40,
		-- Atlas rows for the ends (image px).
		capRow = 0,
		poolRow = 128,
		-- Where each end's goo starts and stops within its 128 px piece (design px), so a run starts and stops
		-- exactly where it is asked to: the cap's left blob starts at 39, its right blob ends at 90; the pool's at
		-- 43 and 85 (each includes the 4 px ink outline; measured from the images).
		capLeftStart = 39,
		capRightEnd = 90,
		poolLeftStart = 43,
		poolRightEnd = 85,
	}),
}

return table.freeze(UIToonConstants)
