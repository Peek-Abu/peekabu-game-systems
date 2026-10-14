local ShiftCurrencyUtils = require(script.Parent.ShiftCurrencyUtils)

return function()
	it("pays associates in dollars", function()
		expect(ShiftCurrencyUtils.SYMBOL).to.equal("$")
	end)

	describe("amount", function()
		it("writes a whole dollar amount", function()
			expect(ShiftCurrencyUtils.amount(45)).to.equal("$45")
		end)

		it("rounds to a whole amount and never reads below zero", function()
			expect(ShiftCurrencyUtils.amount(14.6)).to.equal("$15")
			expect(ShiftCurrencyUtils.amount(-3)).to.equal("$0")
			expect(ShiftCurrencyUtils.amount(0 / 0)).to.equal("$0")
		end)
	end)

	describe("gain", function()
		it("signs what was just earned", function()
			expect(ShiftCurrencyUtils.gain(40)).to.equal("+$40")
			expect(ShiftCurrencyUtils.gain(0)).to.equal("+$0")
		end)
	end)

	describe("signed", function()
		it("puts the dollar sign after an already-formatted sign", function()
			expect(ShiftCurrencyUtils.signed("+40")).to.equal("+$40")
			expect(ShiftCurrencyUtils.signed("-5")).to.equal("-$5")
		end)

		it("prefixes an unsigned amount", function()
			expect(ShiftCurrencyUtils.signed("40")).to.equal("$40")
		end)
	end)

	describe("labels", function()
		it("names the earned total in capitals for the plates and the review", function()
			expect(ShiftCurrencyUtils.earnedLabel()).to.equal("EARNED")
		end)
	end)
end
