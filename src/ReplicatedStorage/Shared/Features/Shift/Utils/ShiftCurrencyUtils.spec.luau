local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftCurrencyUtils = require(script.Parent.ShiftCurrencyUtils)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

return function()
	local NAME = ShiftConstants.CURRENCY_NAME

	it("pays associates in company Scrip", function()
		expect(NAME).to.equal("Scrip")
	end)

	describe("amount", function()
		it("writes a whole amount followed by the currency's name", function()
			expect(ShiftCurrencyUtils.amount(45)).to.equal(`45 {NAME}`)
		end)

		it("rounds to a whole amount and never reads below zero", function()
			expect(ShiftCurrencyUtils.amount(14.6)).to.equal(`15 {NAME}`)
			expect(ShiftCurrencyUtils.amount(-3)).to.equal(`0 {NAME}`)
			expect(ShiftCurrencyUtils.amount(0 / 0)).to.equal(`0 {NAME}`)
		end)
	end)

	describe("gain", function()
		it("signs what was just earned", function()
			expect(ShiftCurrencyUtils.gain(40)).to.equal(`+40 {NAME}`)
			expect(ShiftCurrencyUtils.gain(0)).to.equal(`+0 {NAME}`)
		end)
	end)

	describe("labels", function()
		it("names the earned total in capitals for the plates and the review", function()
			expect(ShiftCurrencyUtils.earnedLabel()).to.equal(`{string.upper(NAME)} EARNED`)
		end)

		it("stamps an earned amount in capitals", function()
			expect(ShiftCurrencyUtils.stamp("+40")).to.equal(`+40 {string.upper(NAME)}`)
		end)
	end)
end
