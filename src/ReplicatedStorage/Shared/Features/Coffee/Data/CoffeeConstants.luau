--!strict
--[=[
	CoffeeConstants: Coffee for the crew (owner 11-08; 30 minutes, owner 11-10): a Robux developer product that gives
	the buyer 30 minutes of coffee time, spent only while a shift runs; while it runs the whole crew's Credits pay is
	doubled, and the buyer is named on the office PA. Static data (spec-exempt).

	@class CoffeeConstants
]=]

-- The product's Roblox id: nil until the owner creates the developer product on the Creator Dashboard (then the buy
-- prompt shows; a voucher still works without it).
local PRODUCT_ID: number? = 3730097825

local CoffeeConstants = {
	-- The product's MarketplaceRegistry key and id.
	PRODUCT_KEY = "coffeeCrew",
	PRODUCT_ID = PRODUCT_ID,
	-- What coffee multiplies the Credits pay by while it runs.
	PAY_SCALE = 2,
	-- One coffee: seconds of shift time (30 minutes).
	SECONDS = 1800,
	-- The Gleam price of the same coffee (owner 11-10), next to the Robux product.
	GLEAM_PRICE = 250,
	-- The Robux price the choice shows until Roblox reports the product's live one (the real price is the product's,
	-- set on the Creator Dashboard). 99 (owner 11-14: "Keep R$ 99"); 250 Gleam at the best pack is about R$ 167.
	ROBUX_PRICE = 99,
	-- How often the server takes a second off the coffee time it is spending.
	TICK_SECONDS = 1,
	-- How often the spent seconds are written to the buyer's slice (each write is an audited profile mutation; a crash
	-- loses at most this many spent seconds, in the buyer's favour).
	SAVE_SECONDS = 10,
	-- The account slice of the buyer's coffee time left (seconds) and when it started (their place in line).
	SLICE = "coffee",
	-- The world entry naming whose coffee runs now and how long it has left ({ buyer, seconds }; the HUD badge).
	-- Absent = no coffee running.
	WORLD_ENTRY = "coffee",
	-- After a purchase, how long the server waits for its save before the PA (a receipt saves before it is told).
	PA_TRIES = 10,
	PA_RETRY_SECONDS = 1,
	TEXT = table.freeze({
		pa = "PA: %s bought coffee! The crew gets 2x pay for 30 minutes!",
		button = "2x PAY",
		badge = "2x PAY",
		review = "Coffee by %s: %sx",
		short = "You need %d Gleam!",
		choiceTitle = "COFFEE FOR THE CREW",
		choiceLine = "2x pay for 30 minutes",
		robux = "%d R$",
		gleam = "%d",
		card = "Credits earned · Coffee %sx",
	}),
}

return table.freeze(CoffeeConstants)
