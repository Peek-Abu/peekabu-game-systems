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

	describe("sales", function()
		local ShopRotationUtils = require(ReplicatedStorage.Shared.Features.Shop.Utils.ShopRotationUtils)
		local NOON = 1792929600
		local DAY = 86400

		it("counts a sale only inside its window, and never one with no end", function()
			expect(ShopPriceRules.saleAt({ price = 5, starts = 100, ends = 200 }, 150).price).to.equal(5)
			expect(ShopPriceRules.saleAt({ price = 5, starts = 100, ends = 200 }, 150).ends).to.equal(200)
			expect(ShopPriceRules.saleAt({ price = 5, starts = 100, ends = 200 }, 99)).to.equal(nil)
			expect(ShopPriceRules.saleAt({ price = 5, starts = 100, ends = 200 }, 200)).to.equal(nil)
			expect(ShopPriceRules.saleAt({ price = 5, ends = 200 }, 0).price).to.equal(5)
			expect(ShopPriceRules.saleAt({ price = 5, starts = 100 }, 150)).to.equal(nil)
			expect(ShopPriceRules.saleAt({ price = 5, ends = 200 }, nil)).to.equal(nil)
			expect(ShopPriceRules.saleAt(nil, 150)).to.equal(nil)
		end)

		it("puts the Featured item and the first picks on the daily sale, never an employee or a bundle", function()
			for day = 0, 30 do
				local now = NOON + day * DAY
				local live = ShopRotationUtils.live(ShopRegistry.all(), now)
				local daily = ShopPriceRules.daily(now)
				local count = 0
				for id, ends in daily do
					count += 1
					expect(ends).to.equal(live.nextRotation)
					local offer = ShopRegistry.get(id)
					expect(#offer.items).to.equal(1)
					expect(CosmeticRegistry.get(id).kind ~= "employee").to.equal(true)
				end
				expect(count <= ShopConstants.DAILY_SALE.picks + 1).to.equal(true)
				for index = 1, math.min(ShopConstants.DAILY_SALE.picks, #live.picks) do
					local pick = live.picks[index]
					if #pick.items == 1 then
						expect(daily[pick.id]).to.equal(live.nextRotation)
					end
				end
			end
		end)

		it(
			"sells a daily-sale item at its percent off with the regular price crossed out, until the shop changes",
			function()
				local now = NOON
				local daily = ShopPriceRules.daily(now)
				local id = next(daily)
				expect(id).to.be.ok()
				local offer = ShopRegistry.get(id)
				local priced = ShopPriceRules.forPlayer(offer, owner(), now)
				expect(priced.price).to.equal(up(offer.price * (100 - ShopConstants.DAILY_SALE.percent) / 100))
				expect(priced.was).to.equal(offer.price)
				expect(priced.saleEnds).to.equal(daily[id])
				-- Without a time, nothing is on sale.
				local plain = ShopPriceRules.forPlayer(offer, owner())
				expect(plain.price).to.equal(offer.price)
				expect(plain.was).to.equal(nil)
				expect(plain.saleEnds).to.equal(nil)
			end
		)

		it("never gives a bundle the daily percent on top of its own discount", function()
			for day = 0, 30 do
				local now = NOON + day * DAY
				for _, offer in ShopRegistry.all() do
					if #offer.items > 1 then
						expect(ShopPriceRules.forPlayer(offer, owner(), now).price).to.equal(offer.price)
					end
				end
			end
		end)

		it("lets an owned item on sale take off only its regular share of a bundle", function()
			local checked = 0
			for day = 0, 60 do
				local now = NOON + day * DAY
				local daily = ShopPriceRules.daily(now)
				for _, offer in ShopRegistry.all() do
					if #offer.items > 1 then
						for _, id in offer.items do
							if daily[id] ~= nil then
								checked += 1
								local all, missing, alone = 0, 0, 0
								for _, other in offer.items do
									all += regular(other)
									if other ~= id then
										missing += regular(other)
										local item = ShopPriceRules.forPlayer(ShopRegistry.get(other), owner(), now)
										alone += item.price
									end
								end
								local priced = ShopPriceRules.forPlayer(offer, owner({ id }), now)
								expect(priced.price).to.equal(
									math.max(1, math.min(up(offer.price * missing / all), alone))
								)
							end
						end
					end
				end
			end
			expect(checked > 0).to.equal(true)
		end)
	end)

	it("prices every bundle 30% off its items alone, rounded down to 10", function()
		for _, offer in ShopRegistry.all() do
			if #offer.items > 1 then
				local alone = 0
				for _, id in offer.items do
					alone += regular(id)
				end
				expect(offer.price).to.equal(math.floor(alone * 0.7 / 10) * 10)
			end
		end
	end)

	it("prices a fixture offer from its own items", function()
		local plain = table.clone(ShopRegistry.get("Cappy.PJ"))
		plain.items = { "Cappy.GloomTouched" }
		expect(ShopPriceRules.forPlayer(plain, owner()).items[1]).to.equal("Cappy.GloomTouched")
	end)

	it("prices from the source offer, so pricing twice changes nothing", function()
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
