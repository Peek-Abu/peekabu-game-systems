--!strict
--[=[
	TypeConstants - Centralized element/type system.
	Defines the valid element types used by moves and battlers.
]=]

local TypeConstants = {
	ELEMENTS = {
		BEAST = "Beast",
		SPIRIT = "Spirit",
		DEMON = "Demon",
		VOID = "Void",
		TECH = "Tech",
		MIND = "Mind",
		DIVINE = "Divine",
		FIRE = "Fire",
		WATER = "Water",
		LIGHTNING = "Lightning",
		LIFE = "Life",
		EARTH = "Earth",
		ICE = "Ice",
		WIND = "Wind",
		NEUTRAL = "Neutral",
		BRAWLER = "Brawler",
	},

	MOVE_CATEGORIES = {
		MELEE = "Melee",
		RANGED = "Ranged",
		BUFF = "Buff",
		HEAL = "Heal",
		STATUS = "Status",
		SPECIAL = "Special",
	},

	DAMAGE_TYPES = {
		BLUNT = "Blunt",
		SLASH = "Slash",
		PIERCE = "Pierce",
		NONE = "None",
	},
}

export type ElementType =
	"Beast"
	| "Spirit"
	| "Demon"
	| "Void"
	| "Tech"
	| "Mind"
	| "Divine"
	| "Fire"
	| "Water"
	| "Lightning"
	| "Life"
	| "Earth"
	| "Ice"
	| "Wind"
	| "Neutral"
	| "Brawler"

export type MoveCategory = "Melee" | "Ranged" | "Buff" | "Heal" | "Status" | "Special"
export type DamageType = "Blunt" | "Slash" | "Pierce" | "None"

return TypeConstants
