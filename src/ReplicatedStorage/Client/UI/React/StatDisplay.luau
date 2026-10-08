--!strict
--[=[
	StatDisplay: how a stat id READS in the UI. `StatConstants` deliberately carries only the mechanics of
	a stat (pool, base, per-point) — a label is a UI concern, so it lives here, next to `RarityDisplay`,
	for the same reason.

	Labels are upper case because every stat line in the authored UI is ("DAMAGE 11 (+2)", "CRITICAL
	STRIKE CHANCE: 32%"). An unregistered id degrades to a readable form of the id itself rather than
	erroring or rendering blank — a stat added to `StatConstants` without a label here shows as
	"ROT ENDURANCE", not nothing, so the omission is visible but harmless.

	Descriptions feed the stat tooltips. Two are the GAME'S OWN copy, lifted from the old `StatsConfigs`
	(strength, rotStrength); the rest are drafted from how this project already documents each stat in
	`StatConstants` — the old game never had a description for them. They are display copy, so edit them
	freely here without touching anything mechanical.

	NOTE ON DAMAGE: the authored card's primary line is the weapon's DAMAGE, which this project does not
	model — weapons carry `statBonuses` keyed by `StatConstants` ids, and there is no damage stat. The
	card shows the item's largest real bonus instead. When weapon damage lands with the combat work, it
	becomes another id with a label here and the card picks it up unchanged.

	@class StatDisplay
]=]

local StatDisplay = {}

-- The authored-style label for each registered stat id.
local LABEL: { [string]: string } = {
	health = "HEALTH",
	stamina = "STAMINA",
	healthRegen = "HEALTH REGEN",
	staminaRegen = "STAMINA REGEN",
	rotStrength = "ROT STRENGTH",
	rotEndurance = "ROT ENDURANCE",
	rotRejuvenation = "ROT REJUVENATION",
	strength = "STRENGTH",
}

-- What each stat DOES, for the row's tooltip. An id with no entry simply has no tooltip.
local DESCRIPTION: { [string]: string } = {
	-- The old game's own wording.
	strength = "Increases overall damage scaling across all types.",
	rotStrength = "A flat bonus to Rot potency, amplifying the damage of all Rot consuming abilities.",
	-- Drafted from this project's own notes on each stat; no authored copy existed.
	health = "Raises your maximum health.",
	stamina = "Raises your maximum stamina, letting you sprint, dodge and block for longer.",
	healthRegen = "Speeds how quickly your health recovers on its own.",
	staminaRegen = "Speeds how quickly your stamina refills after exertion.",
	rotEndurance = "Widens your Rot bar, so you can hold more Rot before it turns on you.",
	rotRejuvenation = "Speeds how quickly your Rot recovers.",
}

--[=[
	What a stat does, for its tooltip; nil when the stat has no copy written for it yet, which the UI
	reads as "show no tooltip" rather than showing an empty one.
	@param id string -- a StatConstants stat id
	@return string?
]=]
function StatDisplay.description(id: string): string?
	return DESCRIPTION[id]
end

--[=[
	The HAND-WRITTEN label for a stat id, or nil when it has none — the question `label` cannot answer,
	since it always returns a string. Not a redundant accessor: for an id with no camelCase hump the
	derived fallback is INDISTINGUISHABLE from an authored entry ("strength" derives to "STRENGTH", which
	is exactly what LABEL holds), so nothing about `label`'s RESULT can prove an id is covered.
	@param id string -- a StatConstants stat id
	@return string?
]=]
function StatDisplay.rawLabel(id: string): string?
	return LABEL[id]
end

--[=[
	The display label for a stat id. Unregistered ids fall back to the id split on camelCase and upper
	cased, so a newly added stat is readable before it is labelled here.
	@param id string -- a StatConstants stat id
	@return string
]=]
function StatDisplay.label(id: string): string
	local known = LABEL[id]
	if known ~= nil then
		return known
	end
	-- camelCase → spaced words, then upper case ("rotEndurance" → "ROT ENDURANCE").
	local spaced = id:gsub("(%l)(%u)", "%1 %2")
	return string.upper(spaced)
end

return StatDisplay
