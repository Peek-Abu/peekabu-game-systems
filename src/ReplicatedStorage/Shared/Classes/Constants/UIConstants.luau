--!strict
--[=[
	UIConstants - Centralized color palettes and UI configuration shared between client and server.
]=]

local TypeConstants = require(script.Parent.TypeConstants)
local ELEMENTS = TypeConstants.ELEMENTS

local UIConstants = {}

UIConstants.ELEMENT_COLORS = {
	[ELEMENTS.BEAST]     = Color3.fromRGB(220, 90,  60),  -- Reddish Brown
	[ELEMENTS.SPIRIT]    = Color3.fromRGB(80,  240, 200), -- Ethereal Teal
	[ELEMENTS.DEMON]     = Color3.fromRGB(160, 40,  80),  -- Crimson/Dark Purple
	[ELEMENTS.VOID]      = Color3.fromRGB(140, 80,  255), -- Deep Void Purple
	[ELEMENTS.TECH]      = Color3.fromRGB(120, 150, 180), -- Steel/Tech Blue
	[ELEMENTS.MIND]      = Color3.fromRGB(230, 110, 210), -- Psychic Pink
	[ELEMENTS.DIVINE]    = Color3.fromRGB(255, 245, 120), -- Golden/Divine Light
	[ELEMENTS.FIRE]      = Color3.fromRGB(255, 110, 30),  -- Fire Orange
	[ELEMENTS.WATER]     = Color3.fromRGB(60,  160, 255), -- Water Blue
	[ELEMENTS.LIGHTNING] = Color3.fromRGB(255, 220, 50),  -- Lightning Yellow
	[ELEMENTS.LIFE]      = Color3.fromRGB(100, 220, 100), -- Life Green
	[ELEMENTS.EARTH]     = Color3.fromRGB(180, 140, 100), -- Earthy Brown
	[ELEMENTS.ICE]       = Color3.fromRGB(150, 220, 255), -- Ice Cyan
	[ELEMENTS.WIND]      = Color3.fromRGB(180, 255, 180), -- Wind Pale Green
	[ELEMENTS.NEUTRAL]   = Color3.fromRGB(200, 200, 200), -- Neutral Grey
	[ELEMENTS.BRAWLER]   = Color3.fromRGB(240, 60,  60),  -- Striking Red
}

UIConstants.STATUS_COLORS = {
	Burn        = Color3.fromRGB(255, 100, 30),
	Burned      = Color3.fromRGB(255, 100, 30),
	Poison      = Color3.fromRGB(160, 80,  200),
	Poisoned    = Color3.fromRGB(160, 80,  200),
	Paralysis   = Color3.fromRGB(240, 210, 50),
	Paralyzed   = Color3.fromRGB(240, 210, 50),
	Freeze      = Color3.fromRGB(150, 220, 255),
	Sleep       = Color3.fromRGB(140, 140, 200),
	Scorch      = Color3.fromRGB(255, 55,  10),
	Scorched    = Color3.fromRGB(255, 55,  10),
	Bleed       = Color3.fromRGB(200, 30,  30),
}

function UIConstants.getElementColor(element: TypeConstants.ElementType?): Color3
	if not element then return UIConstants.ELEMENT_COLORS[ELEMENTS.NEUTRAL] end
	return UIConstants.ELEMENT_COLORS[element] or UIConstants.ELEMENT_COLORS[ELEMENTS.NEUTRAL]
end

function UIConstants.getStatusColor(status: string?): Color3
	return UIConstants.STATUS_COLORS[status or ""] or Color3.fromRGB(160, 160, 160)
end

return UIConstants
