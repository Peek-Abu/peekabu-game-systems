--!strict
--[=[
	Element System with strategic depth beyond simple type advantages.
	
	Elements provide:
	- Elemental resonance (bonus effects when combining same element)
	- Status effect synergies (certain elements inflict/interact with statuses)
	- Tactical advantages (speed, defense, damage patterns)
	- Unique mechanics per element
	
	@class ElementSystem
]=]

local ElementSystem = {}

export type Element = "Fire" | "Water" | "Ice" | "Lightning" | "Earth" | "Wind" | "Light" | "Dark" | "Physical" | "Poison" | "Void"

-- Element properties define strategic characteristics, NOT damage multipliers
local ELEMENT_PROPERTIES = {
	Fire = {
		description = "High damage, burn DoT, glass cannon playstyle",
		statusAffinity = "Burn", -- Can inflict burn
		resonance = "Damage boost when multiple Fire moves used in succession",
		weakness = "Ice", -- Takes extra damage from Ice
		strength = "Wind", -- Deals extra damage to Wind
	},
	Water = {
		description = "Sustain, healing, defensive playstyle",
		statusAffinity = "Regen",
		resonance = "Healing amplification",
		weakness = "Lightning",
		strength = "Fire",
	},
	Ice = {
		description = "Control, freeze, speed reduction",
		statusAffinity = "Freeze",
		resonance = "Increased freeze duration and slow effects",
		weakness = "Fire",
		strength = "Water",
	},
	Lightning = {
		description = "Speed, paralysis, multi-hit combos",
		statusAffinity = "Paralysis",
		resonance = "Bonus actions and speed buffs",
		weakness = "Earth",
		strength = "Water",
	},
	Earth = {
		description = "Tank, defense, counter-attacks",
		statusAffinity = "Shield",
		resonance = "Defense stacking and damage reduction",
		weakness = "Wind",
		strength = "Lightning",
	},
	Wind = {
		description = "Evasion, multi-target, mobility",
		statusAffinity = "Evasion",
		resonance = "Increased dodge chance and multi-target damage",
		weakness = "Fire",
		strength = "Earth",
	},
	Light = {
		description = "Healing, buffs, support",
		statusAffinity = "Blessing",
		resonance = "Team-wide buffs and cleanse",
		weakness = "Dark",
		strength = "Dark",
	},
	Dark = {
		description = "Debuffs, life-steal, curse damage",
		statusAffinity = "Curse",
		resonance = "Life-steal and debuff amplification",
		weakness = "Light",
		strength = "Light",
	},
	Physical = {
		description = "Raw damage, no elemental interactions",
		statusAffinity = "Bleed",
		resonance = "Critical hit chance increase",
		weakness = nil,
		strength = nil,
	},
	Poison = {
		description = "DoT stacking, anti-heal, attrition",
		statusAffinity = "Poison",
		resonance = "Poison stacks faster and stronger",
		weakness = "Light",
		strength = "Physical",
	},
	Void = {
		description = "Nullification, anti-magic, true damage",
		statusAffinity = "Silence",
		resonance = "Ignores shields and resistances",
		weakness = nil,
		strength = nil,
	},
}

-- Damage multipliers for elemental advantages (kept modest to avoid Pokemon-style switching)
local ADVANTAGE_MULTIPLIER = 1.25 -- Only 25% bonus, not 2x like Pokemon
local DISADVANTAGE_MULTIPLIER = 0.85 -- Only 15% reduction

function ElementSystem.getElementProperties(element: Element)
	return ELEMENT_PROPERTIES[element]
end

function ElementSystem.calculateElementalModifier(attackElement: Element, defenderElement: Element): number
	local props = ELEMENT_PROPERTIES[attackElement]
	if not props then return 1.0 end
	
	if props.strength == defenderElement then
		return ADVANTAGE_MULTIPLIER
	elseif props.weakness == defenderElement then
		return DISADVANTAGE_MULTIPLIER
	end
	
	return 1.0
end

return ElementSystem
