--!strict
--[=[
	Tokens: the shared visual language for all game UI — the single source of colour, spacing, radius,
	and type values every primitive and screen reads. Never hardcode a Color3/number at a call site;
	reach for a token, so a look change is one edit here, not a hunt across every screen (the exact
	failure the census found in the old game, which had no token layer at all).

	Values are a deliberate starting palette (dark, cool — consistent with the debugger surface) and
	are TUNABLE: when we convert a real authored screen, the values here get dialled to the game's look.
	The STRUCTURE — semantic names, a spacing scale, a type scale — is the part that stays broad.

	Kept separate from the debugger's own `DebuggerTheme` (which carries debugger-specific helpers); this module
	is values only, so anything can depend on it.

	@class Tokens
]=]

local Tokens = {}

-- COLOUR — semantic, not literal. "surface" not "dark grey", so a re-theme swaps meaning-for-meaning.
Tokens.color = table.freeze({
	-- Surfaces, back (deepest) to front.
	background = Color3.fromRGB(12, 13, 18),
	surface = Color3.fromRGB(20, 22, 29),
	surfaceRaised = Color3.fromRGB(28, 31, 40),
	surfaceOverlay = Color3.fromRGB(40, 44, 56),
	-- Hairlines / dividers.
	border = Color3.fromRGB(46, 51, 64),
	-- Text, by emphasis.
	text = Color3.fromRGB(228, 231, 238),
	textMuted = Color3.fromRGB(142, 149, 165),
	textDisabled = Color3.fromRGB(92, 98, 112),
	onAccent = Color3.fromRGB(12, 13, 18), -- text/icon drawn ON an accent fill
	-- Brand accent.
	accent = Color3.fromRGB(120, 170, 255),
	accentHover = Color3.fromRGB(150, 192, 255),
	-- Semantic status (separate from the accent — never reuse accent for "good/bad").
	success = Color3.fromRGB(120, 210, 150),
	warning = Color3.fromRGB(240, 200, 120),
	danger = Color3.fromRGB(240, 120, 120),
})

-- SPACING — one scale, in pixels. Padding/gaps pick a rung; nothing uses raw numbers.
Tokens.space = table.freeze({
	xs = 4,
	sm = 8,
	md = 12,
	lg = 16,
	xl = 24,
	xxl = 32,
})

-- CORNER RADII — in pixels. `pill` is "fully rounded".
Tokens.radius = table.freeze({
	sm = 4,
	md = 6,
	lg = 10,
	pill = 999,
})

-- STROKE thickness — in pixels.
Tokens.stroke = table.freeze({
	thin = 1,
	thick = 2,
})

-- TYPOGRAPHY — the font roles and the size scale.
-- The face is Venture's own: the authored UI is SourceSansPro throughout (the inventory, the HUD, the
-- shop — every label in the reference place), so the framework uses the same family rather than the
-- Gotham placeholder it started with. This is the "dialled to the game's look" edit the header promises;
-- it is one block, so a re-face stays one block.
Tokens.font = table.freeze({
	body = Enum.Font.SourceSans,
	medium = Enum.Font.SourceSansSemibold,
	bold = Enum.Font.SourceSansBold,
	mono = Enum.Font.Code, -- unchanged: the debug overlay wants a monospace face, not the game's
})
Tokens.textSize = table.freeze({
	xs = 11,
	sm = 13,
	md = 14,
	lg = 16,
	xl = 20,
	xxl = 28,
})

return table.freeze(Tokens)
