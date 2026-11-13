--!strict
--[=[
	ShopRarityLookViewModel: how the shop's backdrop changes with the open item's rarity (owner, 2026-11-14: look B, "the
	backdrop takes the tier"). Every tier gets its own top-to-bottom colours (opaque) and its name written huge and faint
	behind the model, in the same words as its flag (the default tier is CLASSIC). Rays start at Rare and grow stronger up the ladder, and Legendary adds a second layer turning the other
	way. Odd turns dark red, with Gloom goo along the top edge and red screen edges in place of the ink vignette. The
	model itself is never covered (owner: the item must always be clearly visible). ShopScreen hands this to
	ToonBackdrop. Pure.

	@class ShopRarityLookViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

local ShopRarityLookViewModel = {}

export type RayLayer = { color: Color3, transparency: number }

export type Look = {
	top: Color3,
	bottom: Color3,
	rays: RayLayer?,
	-- Legendary's second ray layer, turning the other way.
	counterRays: RayLayer?,
	-- The tier's name behind the model (an outline only), and how faint it is (1 = invisible).
	word: string,
	wordColor: Color3,
	wordTransparency: number,
	-- Odd: Gloom goo along the top edge, and this colour on the screen edges instead of the ink vignette.
	goo: boolean,
	edge: Color3?,
}

local INK = UIToonConstants.COLOR.ink
local WHITE = UIToonConstants.COLOR.white

local LOOKS: { [UIToonConstants.Rarity]: Look } = table.freeze({
	default = {
		top = Color3.fromHex("E6E3EE"),
		bottom = Color3.fromHex("7D7891"),
		word = "CLASSIC",
		wordColor = INK,
		wordTransparency = 0.86,
		goo = false,
	},
	uncommon = {
		top = Color3.fromHex("C2F2AE"),
		bottom = Color3.fromHex("2C8F36"),
		word = "UNCOMMON",
		wordColor = INK,
		wordTransparency = 0.86,
		goo = false,
	},
	rare = {
		top = Color3.fromHex("B4E0FF"),
		bottom = Color3.fromHex("1B5FC0"),
		rays = { color = UIToonConstants.rarity("rare").hi, transparency = 0.6 },
		word = "RARE",
		wordColor = INK,
		wordTransparency = 0.86,
		goo = false,
	},
	epic = {
		top = Color3.fromHex("DDB9FF"),
		bottom = Color3.fromHex("5A1AAE"),
		rays = { color = UIToonConstants.rarity("epic").hi, transparency = 0.5 },
		word = "EPIC",
		wordColor = INK,
		wordTransparency = 0.86,
		goo = false,
	},
	legendary = {
		-- Tuned in play (2026-11-14): on a solid backdrop, white rays on pale yellow vanished.
		top = Color3.fromHex("FFD23F"),
		bottom = Color3.fromHex("E06A00"),
		rays = { color = WHITE, transparency = 0.1 },
		counterRays = { color = UIToonConstants.rarity("legendary").base, transparency = 0.55 },
		word = "LEGENDARY",
		wordColor = INK,
		wordTransparency = 0.86,
		goo = false,
	},
	odd = {
		top = Color3.fromHex("5A0A16"),
		bottom = Color3.fromHex("12020A"),
		word = "ODD",
		wordColor = UIToonConstants.rarity("odd").base,
		wordTransparency = 0.6,
		goo = true,
		edge = Color3.fromHex("FF283C"),
	},
})

function ShopRarityLookViewModel.look(rarity: UIToonConstants.Rarity): Look
	return LOOKS[rarity]
end

return ShopRarityLookViewModel
