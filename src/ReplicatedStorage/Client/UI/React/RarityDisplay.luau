--!strict
--[=[
	RarityDisplay: the DISPLAY metadata for item rarities — a rank (for ordering) and the two authored
	rarity palettes. None of which the domain registry provides on purpose: `ItemConstants.RARITIES` is
	alphabetically sorted and explicitly "does not rank rarities", and colour is a UI concern.

	Venture uses **two different rarity palettes for two different jobs**, which is easy to conflate and
	worth spelling out:

	- **Border** (saturated) — the item slot's rarity border tint. Authored as `Utilities.GetRarityColor2`.
	- **Accent** (pastel) — the item-detail panel's rarity accents (name text, rarity bar). Authored as
	  `UIUtilities.getRarityColorUI`.

	Both are flat tints in the authored UI. The slot template ships with a `UIGradient` under its rarity
	border, but the populate path (`InventoryUIUtilities.UpdateItemFrame`) *destroys* it and sets a flat
	`ImageColor3` — so the gradient is authoring residue, not the shipped look. The detail panel's
	5-stop rarity sheen (`UIUtilities.getRarityColorSequence`) is real, but it belongs to the detail
	panel; it lands here when that panel is skinned, not before.

	Transcribed from the authored palettes in VentureTestingPlace (read-only).

	@class RarityDisplay
]=]

local RarityDisplay = {}

-- Flavour tier, low → high. Used to order items by rarity; NOT a domain ranking (see the header).
local RANK: { [string]: number } = {
	common = 1,
	uncommon = 2,
	rare = 3,
	epic = 4,
	legendary = 5,
	cursed = 6,
}

-- The saturated palette: the item slot's rarity border tint.
local BORDER_COLOR: { [string]: Color3 } = {
	common = Color3.fromRGB(218, 217, 216),
	uncommon = Color3.fromRGB(9, 180, 24),
	rare = Color3.fromRGB(19, 153, 255),
	epic = Color3.fromRGB(141, 41, 255),
	legendary = Color3.fromRGB(190, 141, 28),
	cursed = Color3.fromRGB(173, 4, 35),
}

-- The pastel palette: the item-detail panel's rarity accents.
local ACCENT_COLOR: { [string]: Color3 } = {
	common = Color3.fromRGB(229, 227, 216),
	uncommon = Color3.fromRGB(195, 255, 131),
	rare = Color3.fromRGB(128, 223, 255),
	epic = Color3.fromRGB(226, 151, 255),
	legendary = Color3.fromRGB(255, 136, 0),
	cursed = Color3.fromRGB(220, 89, 85),
}

local UNKNOWN_RANK = 0
-- The authored empty-slot border (`UIUtilities:setFrameBackToDefault`) — a pale blue, not a dimmed
-- rarity colour, so an empty slot reads as "no item" rather than "a common item".
local EMPTY_BORDER_COLOR = Color3.fromRGB(185, 231, 255)

--[=[
	The flavour rank of a rarity (common = 1 … cursed = 6); 0 for an unregistered rarity, so an unknown
	always sorts to the bottom rather than erroring.
	@param rarity string
	@return number
]=]
function RarityDisplay.rank(rarity: string): number
	return RANK[rarity] or UNKNOWN_RANK
end

--[=[
	The item slot's rarity border tint. `nil` means an empty slot, which gets the authored pale-blue
	"no item" border. An unregistered rarity falls back to common — the authored `GetRarityColor2`
	returns black there, which reads as a rendering fault rather than a low-rarity item.
	@param rarity string? -- nil for an empty slot
	@return Color3
]=]
function RarityDisplay.borderColor(rarity: string?): Color3
	if rarity == nil then
		return EMPTY_BORDER_COLOR
	end
	return BORDER_COLOR[rarity] or BORDER_COLOR.common
end

--[=[
	The item-detail panel's rarity accent (the pastel palette); common for an unregistered rarity,
	matching the authored `getRarityColorUI` fallback.
	@param rarity string
	@return Color3
]=]
function RarityDisplay.accentColor(rarity: string): Color3
	return ACCENT_COLOR[rarity] or ACCENT_COLOR.common
end

return RarityDisplay
