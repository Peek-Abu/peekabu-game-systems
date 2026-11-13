local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local ShopPriceRules = require(script.Parent.ShopPriceRules)

return function()
	local STEP = ShopConstants.PRICE_STEP

	local function owner(ids)
		local set = {}
		for _, id in ids or {} do
			set[id] = true
		end
		return function(id)
			return set[id] == true
		end
	end

	local function regular(id)
		return CosmeticRegistry.get(id).price
	end

	-- A bundle of three items at `price` (fixture, so the numbers never depend on today's catalogue).
	local A, B, C = "Prickles.Sheriff", "Prickles.Lasso", "SheriffPack"
	local function bundle(price)
		return { id = "Bundle.Test", items = { A, B, C }, currency = "gleam", price = price, pool = "featured" }
	end
	local function up(value)
		return math.ceil(value / STEP) * STEP
	end

	it("leaves a single item alone", function()
		local offer = ShopRegistry.get(B)
		local priced = ShopPriceRules.forPlayer(offer, owner())
		expect(priced.price).to.equal(offer.price)
		expect(priced.was).to.equal(nil)
	end)

	it("charges a whole bundle its price, crossing out what its items cost alone", function()
		local all = regular(A) + regular(B) + regular(C)
		local priced = ShopPriceRules.forPlayer(bundle(all - 500), owner())
		expect(priced.price).to.equal(all - 500)
		expect(priced.was).to.equal(all)
		-- Not cheaper than its items alone: nothing to cross out.
		expect(ShopPriceRules.forPlayer(bundle(all), owner()).was).to.equal(nil)
	end)

	it("with one item owned, takes off only that item's share at the bundle's discount", function()
		local all = regular(A) + regular(B) + regular(C)
		local price = all - 500
		local missing = regular(A) + regular(C)
		local priced = ShopPriceRules.forPlayer(bundle(price), owner({ B }))
		expect(priced.price).to.equal(up(price * missing / all))
		-- Never the owned item's full price off.
		expect(priced.price > price - regular(B)).to.equal(true)
		expect(priced.was).to.equal(missing)
	end)

	it("with all but one owned, never costs more than that item alone", function()
		local all = regular(A) + regular(B) + regular(C)
		local priced = ShopPriceRules.forPlayer(bundle(all - 500), owner({ A, B }))
		expect(priced.price).to.equal(math.min(up((all - 500) * regular(C) / all), regular(C)))
		expect(priced.price <= regular(C)).to.equal(true)
		-- A bundle priced above its items: the missing item alone caps it.
		local dear = ShopPriceRules.forPlayer(bundle(all * 3), owner({ A, B }))
		expect(dear.price).to.equal(regular(C))
	end)

	it("never goes below 1", function()
		local priced = ShopPriceRules.forPlayer(bundle(1), owner({ A, B }))
		expect(priced.price >= 1).to.equal(true)
	end)

	it("keeps an all-owned bundle's own price (the Shop says Owned)", function()
		local priced = ShopPriceRules.forPlayer(bundle(1500), owner({ A, B, C }))
		expect(priced.price).to.equal(1500)
	end)

	it("prices from the registered offer, so pricing twice changes nothing", function()
		for _, offer in ShopRegistry.all() do
			if #offer.items > 1 then
				local once = ShopPriceRules.forPlayer(offer, owner({ offer.items[1] }))
				local twice = ShopPriceRules.forPlayer(once, owner({ offer.items[1] }))
				expect(twice.price).to.equal(once.price)
				expect(twice.was).to.equal(once.was)
			end
		end
	end)
end
