local MarketplaceRegistry = require(script.Parent.MarketplaceRegistry)

-- The registry is a live singleton: ids here are far from any real catalogue entry, and each key is
-- registered at most once per VM.
local function ensureProduct(key, productId)
	if MarketplaceRegistry.product(key) == nil then
		MarketplaceRegistry.registerProduct(key, { productId = productId })
	end
end

local function ensurePass(key, passId)
	if MarketplaceRegistry.pass(key) == nil then
		MarketplaceRegistry.registerPass(key, { passId = passId })
	end
end

return function()
	describe("products", function()
		it("registers a product and finds it by key and by id", function()
			ensureProduct("spec-gems", 990000001)
			expect(MarketplaceRegistry.product("spec-gems").productId).to.equal(990000001)
			expect(MarketplaceRegistry.productKeyFor(990000001)).to.equal("spec-gems")
			expect(MarketplaceRegistry.productKeyFor(990000999)).to.equal(nil)
		end)

		it("rejects a duplicate key or id", function()
			ensureProduct("spec-dup-product", 990000002)
			expect(function()
				MarketplaceRegistry.registerProduct("spec-dup-product", { productId = 990000003 })
			end).to.throw()
			expect(function()
				MarketplaceRegistry.registerProduct("spec-other-product", { productId = 990000002 })
			end).to.throw()
			expect(MarketplaceRegistry.product("spec-other-product")).to.equal(nil)
		end)

		it("rejects an id that is not a positive whole number", function()
			expect(function()
				MarketplaceRegistry.registerProduct("spec-bad-product", { productId = 0 })
			end).to.throw()
			expect(function()
				MarketplaceRegistry.registerProduct("spec-bad-product", { productId = 1.5 })
			end).to.throw()
			expect(MarketplaceRegistry.product("spec-bad-product")).to.equal(nil)
		end)
	end)

	describe("passes", function()
		it("registers a pass, finds it by key and id, and lists its key", function()
			ensurePass("spec-vip", 990000101)
			expect(MarketplaceRegistry.pass("spec-vip").passId).to.equal(990000101)
			expect(MarketplaceRegistry.passKeyFor(990000101)).to.equal("spec-vip")
			expect(table.find(MarketplaceRegistry.passKeys(), "spec-vip")).to.be.ok()
		end)

		it("rejects a duplicate key or id and a bad id", function()
			ensurePass("spec-dup-pass", 990000102)
			expect(function()
				MarketplaceRegistry.registerPass("spec-dup-pass", { passId = 990000103 })
			end).to.throw()
			expect(function()
				MarketplaceRegistry.registerPass("spec-other-pass", { passId = 990000102 })
			end).to.throw()
			expect(function()
				MarketplaceRegistry.registerPass("spec-bad-pass", { passId = -4 })
			end).to.throw()
		end)

		it("rejects an empty key", function()
			expect(function()
				MarketplaceRegistry.registerPass("", { passId = 990000104 })
			end).to.throw()
		end)
	end)
end
