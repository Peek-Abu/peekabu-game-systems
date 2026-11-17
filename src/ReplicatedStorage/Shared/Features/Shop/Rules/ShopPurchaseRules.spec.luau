local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoffeeConstants = require(ReplicatedStorage.Shared.Features.Coffee.Data.CoffeeConstants)
local DealConstants = require(ReplicatedStorage.Shared.Features.Deal.Data.DealConstants)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopPurchaseRules = require(script.Parent.ShopPurchaseRules)

return function()
	describe("forProduct", function()
		it("turns every Gleam bundle into a Gleam purchase of its amount", function()
			for _, bundle in ShopConstants.BUNDLES do
				local purchase = ShopPurchaseRules.forProduct(bundle.key)
				expect(purchase).to.be.ok()
				expect(purchase.kind).to.equal("gleam")
				expect(purchase.key).to.equal(bundle.key)
				expect(purchase.amount).to.equal(bundle.gleam)
			end
		end)

		it("turns the coffee product into a coffee purchase of its minutes", function()
			local purchase = ShopPurchaseRules.forProduct(CoffeeConstants.PRODUCT_KEY)
			expect(purchase).to.be.ok()
			expect(purchase.kind).to.equal("coffee")
			expect(purchase.amount).to.equal(CoffeeConstants.SECONDS // 60)
		end)

		it("shows a deal's Gleam (its picks get their own reveal); a deal with no Gleam shows nothing", function()
			for _, id in DealConstants.ORDER do
				local deal = DealConstants.DEALS[id]
				local purchase = ShopPurchaseRules.forProduct(deal.productKey)
				if deal.gleam > 0 then
					expect(purchase).to.be.ok()
					expect(purchase.kind).to.equal("gleam")
					expect(purchase.amount).to.equal(deal.gleam)
				else
					expect(purchase).to.equal(nil)
				end
			end
		end)

		it("is nil for a product it does not know", function()
			expect(ShopPurchaseRules.forProduct("dealSomething")).to.equal(nil)
			expect(ShopPurchaseRules.forProduct("")).to.equal(nil)
		end)
	end)

	describe("forPass", function()
		it("turns a pass key into a pass purchase", function()
			local purchase = ShopPurchaseRules.forPass("bigCrew")
			expect(purchase.kind).to.equal("pass")
			expect(purchase.key).to.equal("bigCrew")
			expect(purchase.amount).to.equal(1)
		end)

		it("is nil for an empty key", function()
			expect(ShopPurchaseRules.forPass("")).to.equal(nil)
		end)
	end)

	describe("parse", function()
		it("keeps a well-formed purchase", function()
			local purchase = ShopPurchaseRules.parse({ kind = "gleam", key = "gleam880", amount = 880 })
			expect(purchase).to.be.ok()
			expect(purchase.kind).to.equal("gleam")
			expect(purchase.amount).to.equal(880)
		end)

		it("refuses an unknown kind, a missing key or a bad amount", function()
			expect(ShopPurchaseRules.parse({ kind = "robux", key = "x", amount = 1 })).to.equal(nil)
			expect(ShopPurchaseRules.parse({ kind = "gleam", key = "", amount = 1 })).to.equal(nil)
			expect(ShopPurchaseRules.parse({ kind = "gleam", key = "x", amount = 0 })).to.equal(nil)
			expect(ShopPurchaseRules.parse({ kind = "gleam", key = "x", amount = 1.5 })).to.equal(nil)
		end)
	end)

	describe("shows", function()
		it("shows Gleam and passes wherever they were bought (they wait for the hub)", function()
			expect(ShopPurchaseRules.shows({ kind = "gleam", key = "gleam100", amount = 100 }, false)).to.equal(true)
			expect(ShopPurchaseRules.shows({ kind = "pass", key = "bigCrew", amount = 1 }, false)).to.equal(true)
		end)

		it("shows coffee only when bought in the hub (in a shift the office PA is the thank-you)", function()
			local coffee = { kind = "coffee", key = CoffeeConstants.PRODUCT_KEY, amount = 30 }
			expect(ShopPurchaseRules.shows(coffee, true)).to.equal(true)
			expect(ShopPurchaseRules.shows(coffee, false)).to.equal(false)
		end)
	end)
end
