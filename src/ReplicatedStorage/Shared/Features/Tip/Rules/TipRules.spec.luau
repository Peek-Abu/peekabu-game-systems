local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TipRules = require(ReplicatedStorage.Shared.Features.Tip.Rules.TipRules)

return function()
	describe("validate", function()
		it("accepts an empty list and a list of seen tips", function()
			expect(TipRules.validate({ seen = {} })).to.equal(true)
			expect(TipRules.validate({ seen = { firstCatch = true, overtime = true } })).to.equal(true)
		end)

		it("refuses a missing list, a non-true mark and a bad key", function()
			expect(TipRules.validate(nil)).to.equal(false)
			expect(TipRules.validate({})).to.equal(false)
			expect(TipRules.validate({ seen = { firstCatch = false } })).to.equal(false)
			expect(TipRules.validate({ seen = { [1] = true } })).to.equal(false)
		end)
	end)

	describe("shouldShow", function()
		it("shows a known tip the player has not seen, while tips are on", function()
			expect(TipRules.shouldShow({ seen = {} }, "firstCatch", true)).to.equal(true)
		end)

		it("never shows a tip twice", function()
			expect(TipRules.shouldShow({ seen = { firstCatch = true } }, "firstCatch", true)).to.equal(false)
		end)

		it("shows nothing while tips are off", function()
			expect(TipRules.shouldShow({ seen = {} }, "firstCatch", false)).to.equal(false)
		end)

		it("shows nothing for an unknown tip", function()
			expect(TipRules.shouldShow({ seen = {} }, "nope", true)).to.equal(false)
		end)
	end)

	describe("clear", function()
		it("forgets every seen tip, so each shows again", function()
			local tips = { seen = { firstCatch = true, other = true } }
			expect(TipRules.clear(tips)).to.equal(true)
			expect(next(tips.seen)).to.equal(nil)
			expect(TipRules.shouldShow(tips, "firstCatch", true)).to.equal(true)
			expect(TipRules.validate(tips)).to.equal(true)
		end)

		it("reports no change when nothing was seen", function()
			expect(TipRules.clear({ seen = {} })).to.equal(false)
		end)
	end)
end
