--!strict
--[=[
	CoffeeConstants: Coffee for the crew (owner 11-08): a Robux developer product bought during a shift that doubles the
	whole crew's Credits pay for that one shift, the buyer named on the office PA. Static data (spec-exempt).

	@class CoffeeConstants
]=]

-- The product's Roblox id: nil until the owner creates the developer product on the Creator Dashboard (then the buy
-- prompt shows; a voucher still works without it).
local PRODUCT_ID: number? = nil

local CoffeeConstants = {
	-- The product's MarketplaceRegistry key and id.
	PRODUCT_KEY = "coffeeCrew",
	PRODUCT_ID = PRODUCT_ID,
	-- What coffee multiplies the shift's Credits pay by.
	PAY_SCALE = 2,
	-- The account slice of unspent coffees (a second buy in the same shift, or one that lands with no shift running).
	SLICE = "coffee",
	-- The world entry naming who bought this shift's coffee (the HUD badge); absent = no coffee.
	WORLD_ENTRY = "coffee",
	-- After a purchase, how long the server keeps trying to spend the new voucher (its save may still be landing).
	SPEND_TRIES = 10,
	SPEND_RETRY_SECONDS = 1,
	TEXT = table.freeze({
		pa = "PA: %s bought coffee! 2x pay for the crew!",
		button = "2x PAY",
		free = "FREE",
		badge = "2x PAY",
		review = "Coffee by %s: %dx",
		card = "Credits earned · Coffee %dx",
	}),
}

return table.freeze(CoffeeConstants)
