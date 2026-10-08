--!strict
--[=[
	CustomizationSoulColorRegistry: the catalog of soul colours and the pure resolution of an id into renderable
	colour data.

	A character has exactly ONE soul colour, stored on the per-slot `Appearance` (customization design
	spec, Decision 5 of 5b). It is deliberately NOT an owned collection in `entitlements`: a roll
	REPLACES it, so modelling a set would communicate "collection" while behaving as "single".

	MULTI-HUE ids are a real thing, inherited from the old game: `"blue-green"` is ONE soul carrying two
	hues, not two souls. The hyphen-joined form is the id, and composing its gradient is the only part of
	the old `SoulColor` module worth porting — that logic is pure maths, not the Instance-mutation and
	gacha weighting around it.

	NOT ported: the weighted roll (Common/Uncommon/Rare/Double), its rarity tables, and the spinner.
	Those are lootbox/economy concerns for a later phase; 5b ships storage, selection and resolution so
	VFX has something to read.

	@class CustomizationSoulColorRegistry
]=]

--[=[
	One registered hue.
	@interface SoulColorDef
	.color { r: number, g: number, b: number } -- 0..255 integers, the hue's dominant colour
]=]
export type SoulColorDef = {
	color: { r: number, g: number, b: number },
}

-- The hue catalog, carried over from the old game's palette. Values are the old module's dominant
-- colours converted to the single 0..255 integer convention this codebase uses everywhere.
local COLORS: { [string]: SoulColorDef } = {
	blue = { color = { r = 69, g = 135, b = 255 } },
	green = { color = { r = 143, g = 255, b = 82 } },
	purple = { color = { r = 147, g = 1, b = 91 } },
	pink = { color = { r = 255, g = 106, b = 223 } },
	orange = { color = { r = 145, g = 79, b = 14 } },
	yellow = { color = { r = 255, g = 140, b = 25 } },
	salmon = { color = { r = 121, g = 93, b = 89 } },
	mint = { color = { r = 120, g = 152, b = 133 } },
	white = { color = { r = 255, g = 255, b = 255 } },
	black = { color = { r = 0, g = 0, b = 0 } },
}

-- The separator that joins hues into one multi-hue soul id ("blue-green").
local HUE_SEPARATOR = "-"

-- How many hues one soul may carry. The old module capped combining at 3; kept so an id cannot grow
-- unboundedly through repeated rolls once the roll layer exists.
local MAX_HUES = 3

local NAMES: { string } = {}
for name in COLORS do
	table.insert(NAMES, name)
end
table.sort(NAMES)

for name, def in COLORS do
	for _, component in { def.color.r, def.color.g, def.color.b } do
		assert(
			component == math.floor(component) and component >= 0 and component <= 255,
			`[CustomizationSoulColorRegistry] "{name}" has a component outside [0, 255]`
		)
	end
	assert(
		not string.find(name, HUE_SEPARATOR, 1, true),
		`[CustomizationSoulColorRegistry] hue "{name}" must not contain "{HUE_SEPARATOR}" — that joins a multi-hue id`
	)
end

local CustomizationSoulColorRegistry = {
	MAX_HUES = MAX_HUES,
	HUE_SEPARATOR = HUE_SEPARATOR,
}

--[=[
	Splits a soul-colour id into its hues. A single-hue id yields one entry.
	@param id string
	@return { string }
]=]
function CustomizationSoulColorRegistry.hues(id: string): { string }
	return string.split(id, HUE_SEPARATOR)
end

--[=[
	True iff `id` names a registered soul colour: every hue must be registered, there must be at least
	one, and no more than MAX_HUES. Order is significant — "blue-green" and "green-blue" are different
	ids that render as different gradients, so neither is normalised into the other.
	@param id string
	@return boolean
]=]
function CustomizationSoulColorRegistry.isRegistered(id: string): boolean
	if type(id) ~= "string" or id == "" then
		return false
	end
	local hues = CustomizationSoulColorRegistry.hues(id)
	if #hues == 0 or #hues > MAX_HUES then
		return false
	end
	for _, hue in hues do
		if COLORS[hue] == nil then
			return false
		end
	end
	return true
end

--[=[
	Every registered single hue, sorted — the building blocks a Cmdr enum or UI list offers. Multi-hue
	ids are composed from these rather than enumerated, since the combinations are not a fixed set.
	@return { string }
]=]
function CustomizationSoulColorRegistry.hueNames(): { string }
	return NAMES
end

--[=[
	The dominant colour for `id`: a single hue's own colour, or the COMPONENT-WISE MEAN of a multi-hue
	id's hues. The mean is what lets a caller that can only use one colour (a tint, an icon) represent a
	two-hue soul sensibly, rather than silently picking the first hue.
	@param id string
	@return { r: number, g: number, b: number }? -- nil when the id is not registered
]=]
function CustomizationSoulColorRegistry.dominantColor(id: string): { r: number, g: number, b: number }?
	if not CustomizationSoulColorRegistry.isRegistered(id) then
		return nil
	end
	local hues = CustomizationSoulColorRegistry.hues(id)
	local r, g, b = 0, 0, 0
	for _, hue in hues do
		local def = COLORS[hue]
		r += def.color.r
		g += def.color.g
		b += def.color.b
	end
	local count = #hues
	-- Floored so the result stays an integer triple, matching the one colour convention.
	return { r = math.floor(r / count), g = math.floor(g / count), b = math.floor(b / count) }
end

--[=[
	The gradient stops for `id`, in hue order — one stop per hue, each with its position in [0, 1]. A
	single-hue soul yields ONE stop at 0, which a consumer renders as a flat colour.

	Returned as plain data rather than a `ColorSequence` so this module stays pure and testable, and so
	both realms can consume it; the VFX layer builds the engine type from these stops.
	@param id string
	@return { { position: number, color: { r: number, g: number, b: number } } }? -- nil when unregistered
]=]
function CustomizationSoulColorRegistry.gradient(
	id: string
): { { position: number, color: { r: number, g: number, b: number } } }?
	if not CustomizationSoulColorRegistry.isRegistered(id) then
		return nil
	end
	local hues = CustomizationSoulColorRegistry.hues(id)
	local stops = {}
	local lastIndex = #hues - 1
	for index, hue in hues do
		local def = COLORS[hue]
		-- Single hue -> one stop at 0; otherwise spread evenly across [0, 1].
		local position = if lastIndex == 0 then 0 else (index - 1) / lastIndex
		table.insert(stops, { position = position, color = { r = def.color.r, g = def.color.g, b = def.color.b } })
	end
	return stops
end

return CustomizationSoulColorRegistry
