--!strict
--[=[
	TypeChart - Effectiveness matrix for all 15 element types.
	Multipliers (Refined):
	- Super Effective: 1.5x
	- Resisted: 0.75x
	- Immune: 0.0x
]=]

local TypeConstants = require(script.Parent.TypeConstants)
local ELEMENTS = TypeConstants.ELEMENTS

type ElementType = TypeConstants.ElementType
type Chart = { [ElementType]: { [ElementType]: number } }

local EFFECTIVE = 1.5
local RESISTED = 0.75
local IMMUNE = 0.0

local TypeChart: Chart = {
	[ELEMENTS.FIRE] = {
		[ELEMENTS.ICE]       = EFFECTIVE,
		[ELEMENTS.WIND]      = EFFECTIVE,
		[ELEMENTS.LIFE]      = EFFECTIVE,
		[ELEMENTS.FIRE]      = RESISTED,
		[ELEMENTS.WATER]     = RESISTED,
		[ELEMENTS.EARTH]     = RESISTED,
	},
	[ELEMENTS.WATER] = {
		[ELEMENTS.FIRE]      = EFFECTIVE,
		[ELEMENTS.EARTH]     = EFFECTIVE,
		[ELEMENTS.WATER]     = RESISTED,
		[ELEMENTS.LIGHTNING] = RESISTED,
		[ELEMENTS.LIFE]      = RESISTED,
	},
	[ELEMENTS.LIGHTNING] = {
		[ELEMENTS.WATER]     = EFFECTIVE,
		[ELEMENTS.TECH]      = EFFECTIVE,
		[ELEMENTS.WIND]      = EFFECTIVE,
		[ELEMENTS.LIGHTNING] = RESISTED,
		[ELEMENTS.EARTH]     = IMMUNE,
	},
	[ELEMENTS.EARTH] = {
		[ELEMENTS.LIGHTNING] = EFFECTIVE,
		[ELEMENTS.TECH]      = EFFECTIVE,
		[ELEMENTS.FIRE]      = EFFECTIVE,
		[ELEMENTS.WIND]      = RESISTED,
		[ELEMENTS.WATER]     = RESISTED,
		[ELEMENTS.LIFE]      = RESISTED,
	},
	[ELEMENTS.WIND] = {
		[ELEMENTS.EARTH]     = EFFECTIVE,
		[ELEMENTS.LIFE]      = EFFECTIVE,
		[ELEMENTS.LIGHTNING] = RESISTED,
		[ELEMENTS.FIRE]      = RESISTED,
		[ELEMENTS.ICE]       = RESISTED,
	},
	[ELEMENTS.ICE] = {
		[ELEMENTS.WIND]      = EFFECTIVE,
		[ELEMENTS.LIFE]      = EFFECTIVE,
		[ELEMENTS.BEAST]     = EFFECTIVE,
		[ELEMENTS.FIRE]      = RESISTED,
		[ELEMENTS.WATER]     = RESISTED,
		[ELEMENTS.ICE]       = RESISTED,
	},
	[ELEMENTS.LIFE] = {
		[ELEMENTS.WATER]     = EFFECTIVE,
		[ELEMENTS.EARTH]     = EFFECTIVE,
		[ELEMENTS.SPIRIT]    = EFFECTIVE,
		[ELEMENTS.FIRE]      = RESISTED,
		[ELEMENTS.ICE]       = RESISTED,
		[ELEMENTS.WIND]      = RESISTED,
	},
	[ELEMENTS.TECH] = {
		[ELEMENTS.BEAST]     = EFFECTIVE,
		[ELEMENTS.MIND]      = EFFECTIVE,
		[ELEMENTS.ICE]       = EFFECTIVE,
		[ELEMENTS.LIGHTNING] = RESISTED,
		[ELEMENTS.EARTH]     = RESISTED,
		[ELEMENTS.FIRE]      = RESISTED,
	},
	[ELEMENTS.BEAST] = {
		[ELEMENTS.LIFE]      = EFFECTIVE,
		[ELEMENTS.NEUTRAL]   = EFFECTIVE,
		[ELEMENTS.MIND]      = EFFECTIVE,
		[ELEMENTS.TECH]      = RESISTED,
		[ELEMENTS.DEMON]     = RESISTED,
		[ELEMENTS.SPIRIT]    = RESISTED,
	},
	[ELEMENTS.MIND] = {
		[ELEMENTS.BEAST]     = EFFECTIVE,
		[ELEMENTS.DEMON]     = EFFECTIVE,
		[ELEMENTS.TECH]      = EFFECTIVE,
		[ELEMENTS.VOID]      = RESISTED,
		[ELEMENTS.MIND]      = RESISTED,
		[ELEMENTS.SPIRIT]    = RESISTED,
	},
	[ELEMENTS.DEMON] = {
		[ELEMENTS.SPIRIT]    = EFFECTIVE,
		[ELEMENTS.MIND]      = EFFECTIVE,
		[ELEMENTS.BEAST]     = EFFECTIVE,
		[ELEMENTS.DIVINE]    = RESISTED,
		[ELEMENTS.VOID]      = RESISTED,
	},
	[ELEMENTS.SPIRIT] = {
		[ELEMENTS.DEMON]     = EFFECTIVE,
		[ELEMENTS.TECH]      = EFFECTIVE,
		[ELEMENTS.NEUTRAL]   = EFFECTIVE,
		[ELEMENTS.LIFE]      = RESISTED,
		[ELEMENTS.DIVINE]    = RESISTED,
		[ELEMENTS.VOID]      = RESISTED,
	},
	[ELEMENTS.DIVINE] = {
		[ELEMENTS.DEMON]     = EFFECTIVE,
		[ELEMENTS.VOID]      = EFFECTIVE,
		[ELEMENTS.SPIRIT]    = EFFECTIVE,
		[ELEMENTS.VOID]      = RESISTED,
	},
	[ELEMENTS.VOID] = {
		[ELEMENTS.DIVINE]    = EFFECTIVE,
		[ELEMENTS.SPIRIT]    = EFFECTIVE,
		[ELEMENTS.MIND]      = EFFECTIVE,
		[ELEMENTS.DIVINE]    = RESISTED,
	},
	[ELEMENTS.NEUTRAL] = {
		[ELEMENTS.BRAWLER]   = RESISTED,
	},
	[ELEMENTS.BRAWLER] = {
		[ELEMENTS.NEUTRAL]   = EFFECTIVE,
		[ELEMENTS.TECH]      = EFFECTIVE,
		[ELEMENTS.ICE]       = EFFECTIVE,
		[ELEMENTS.SPIRIT]    = RESISTED,
		[ELEMENTS.DEMON]     = RESISTED,
		[ELEMENTS.MIND]      = RESISTED,
	}
}

local TypeChartUtils = {}

function TypeChartUtils.getMultiplier(attackerType: ElementType, defenderType: ElementType): number
	local attackerChart = TypeChart[attackerType]
	if not attackerChart then return 1.0 end
	
	return attackerChart[defenderType] or 1.0
end

function TypeChartUtils.getEffectivenessMessage(multiplier: number): string?
	if multiplier >= EFFECTIVE then
		return "Super effective!"
	elseif multiplier > 0 and multiplier <= RESISTED then
		return "Resisted..."
	elseif multiplier == 0 then
		return "Immune!"
	end
	return nil
end

return TypeChartUtils
