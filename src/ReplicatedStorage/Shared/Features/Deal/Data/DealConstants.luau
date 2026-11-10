--!strict
--[=[
	DealConstants: the one-time deals (owner 11-09): Robux developer products a player buys once per account, then
	picks what they get. Pick a Legendary (399 R$): one Legendary skin bundle for an employee they have hired, plus
	500 Gleam. Pick a New Hire (349 R$): hire Cappy or Prickles now, with that employee's Legendary skin bundle.
	Nothing is random: the player always chooses. Static data (spec-exempt).

	@class DealConstants
]=]

-- A deal's id ("pickLegendary", "pickNewHire"); DealRules.parseDeal checks one.
export type DealId = string

export type Deal = {
	id: DealId,
	-- The MarketplaceRegistry key, and the Roblox developer product id: nil until the owner creates the product on
	-- the Creator Dashboard (the card then says "Soon" and nothing can be bought).
	productKey: string,
	productId: number?,
	-- The Robux price shown on the card (the real price is the product's, set on the Dashboard).
	robux: number,
	-- Gleam added with the purchase (in the receipt's own save).
	gleam: number,
	-- "% off", measured against buying the same Gleam at the best bundle price (1,500 Gleam = 549 R$).
	off: number,
	-- Words, kid reading level.
	name: string,
	line: string,
	chooseTitle: string,
	chooseLine: string,
}

-- The product ids: nil until the owner creates them (then put the numbers here).
local LEGENDARY_PRODUCT: number? = 3730253755
local NEW_HIRE_PRODUCT: number? = 3730253877

local DEALS: { [string]: Deal } = {
	pickLegendary = {
		id = "pickLegendary",
		productKey = "dealPickLegendary",
		productId = LEGENDARY_PRODUCT,
		robux = 399,
		gleam = 500,
		off = 45,
		name = "Pick a Legendary",
		line = "Pick any Legendary skin + its emote and stickers. Plus 500 Gleam!",
		chooseTitle = "PICK YOUR LEGENDARY!",
		chooseLine = "Pick one. It comes with its emote and stickers.",
	},
	pickNewHire = {
		id = "pickNewHire",
		productKey = "dealPickNewHire",
		productId = NEW_HIRE_PRODUCT,
		robux = 349,
		gleam = 0,
		off = 36,
		name = "Pick a New Hire",
		line = "Hire a new employee now + their Legendary skin, emote and stickers!",
		chooseTitle = "PICK YOUR NEW HIRE!",
		chooseLine = "Pick one. They come with their Legendary skin.",
	},
}

-- The order the shop shows them in.
local ORDER: { DealId } = { "pickLegendary", "pickNewHire" }

local DealConstants = {
	DEALS = DEALS,
	ORDER = ORDER,
	-- The account slice: which deals were bought, and the picks not chosen yet.
	SLICE = "deals",
	-- The chooser scene.
	SCENE = "dealChooser",
	TEXT = table.freeze({
		ribbon = "ONE-TIME DEAL",
		once = "1 per player · you pick it, nothing random",
		soon = "Soon",
		pick = "Pick!",
	}),
}

return table.freeze(DealConstants)
