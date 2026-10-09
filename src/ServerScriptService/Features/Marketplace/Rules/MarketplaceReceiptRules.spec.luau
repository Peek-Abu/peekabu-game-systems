local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketplaceConstants = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceConstants)
local MarketplaceReceiptRules = require(script.Parent.MarketplaceReceiptRules)

return function()
	describe("record", function()
		it("records a new purchase id once", function()
			local receipts = { ids = {} }
			expect(MarketplaceReceiptRules.record(receipts, "p1", 3)).to.equal(true)
			expect(MarketplaceReceiptRules.has(receipts, "p1")).to.equal(true)
			expect(MarketplaceReceiptRules.record(receipts, "p1", 3)).to.equal(false)
			expect(#receipts.ids).to.equal(1)
		end)

		it("drops the oldest ids beyond the cap", function()
			local receipts = { ids = {} }
			for index = 1, 4 do
				MarketplaceReceiptRules.record(receipts, `p{index}`, 3)
			end
			expect(#receipts.ids).to.equal(3)
			expect(MarketplaceReceiptRules.has(receipts, "p1")).to.equal(false)
			expect(receipts.ids[1]).to.equal("p2")
			expect(receipts.ids[3]).to.equal("p4")
		end)
	end)

	describe("validateReceipts", function()
		it("accepts a well-formed history", function()
			expect(MarketplaceReceiptRules.validateReceipts({ ids = { "a", "b" } })).to.equal(true)
		end)

		it("rejects non-strings, duplicates and an over-long history", function()
			expect(MarketplaceReceiptRules.validateReceipts({ ids = { "a", 2 } })).to.equal(false)
			expect(MarketplaceReceiptRules.validateReceipts({ ids = { "a", "a" } })).to.equal(false)
			expect(MarketplaceReceiptRules.validateReceipts({ ids = "a" })).to.equal(false)
			local long = {}
			for index = 1, MarketplaceConstants.RECEIPT_HISTORY + 1 do
				long[index] = tostring(index)
			end
			expect(MarketplaceReceiptRules.validateReceipts({ ids = long })).to.equal(false)
		end)
	end)

	describe("validatePremium", function()
		it("accepts whole numbers within the cap", function()
			expect(MarketplaceReceiptRules.validatePremium({ balance = 0 })).to.equal(true)
			expect(MarketplaceReceiptRules.validatePremium({ balance = MarketplaceConstants.MAX_PREMIUM })).to.equal(
				true
			)
		end)

		it("rejects negatives, fractions, NaN and values over the cap", function()
			expect(MarketplaceReceiptRules.validatePremium({ balance = -1 })).to.equal(false)
			expect(MarketplaceReceiptRules.validatePremium({ balance = 1.5 })).to.equal(false)
			expect(MarketplaceReceiptRules.validatePremium({ balance = 0 / 0 })).to.equal(false)
			expect(MarketplaceReceiptRules.validatePremium({ balance = MarketplaceConstants.MAX_PREMIUM + 1 })).to.equal(
				false
			)
			expect(MarketplaceReceiptRules.validatePremium({ balance = "10" })).to.equal(false)
		end)
	end)
end
