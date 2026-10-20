local ShiftLivesRules = require(script.Parent.ShiftLivesRules)

return function()
	describe("starting", function()
		it("is the base with no modifiers", function()
			expect(ShiftLivesRules.starting(3, {})).to.equal(3)
		end)

		it("applies a modifier", function()
			expect(ShiftLivesRules.starting(3, {
				function(n)
					return n + 1
				end,
			})).to.equal(4)
		end)

		it("applies modifiers in order", function()
			expect(ShiftLivesRules.starting(3, {
				function(n)
					return n * 2
				end,
				function(n)
					return n - 1
				end,
			})).to.equal(5)
		end)

		it("never goes below 1", function()
			expect(ShiftLivesRules.starting(3, {
				function()
					return -5
				end,
			})).to.equal(1)
		end)

		it("floors a fraction", function()
			expect(ShiftLivesRules.starting(3, {
				function(n)
					return n + 0.7
				end,
			})).to.equal(3)
		end)
	end)

	describe("spend", function()
		it("takes one life", function()
			local left, out = ShiftLivesRules.spend(3)
			expect(left).to.equal(2)
			expect(out).to.equal(false)
		end)

		it("knocks out on the last life", function()
			local left, out = ShiftLivesRules.spend(1)
			expect(left).to.equal(0)
			expect(out).to.equal(true)
		end)

		it("stays at 0 when none are left", function()
			local left, out = ShiftLivesRules.spend(0)
			expect(left).to.equal(0)
			expect(out).to.equal(true)
		end)
	end)
end
