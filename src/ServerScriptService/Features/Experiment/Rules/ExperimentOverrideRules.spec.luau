local ExperimentOverrideRules = require(script.Parent.ExperimentOverrideRules)

return function()
	describe("parse", function()
		it("reads id=variant pairs, trimming spaces", function()
			local parsed = ExperimentOverrideRules.parse(" exp-clean=3s , exp-rehire = 10s ")
			expect(parsed["exp-clean"]).to.equal("3s")
			expect(parsed["exp-rehire"]).to.equal("10s")
		end)

		it("drops unknown ids, unknown variants and malformed pairs", function()
			local parsed = ExperimentOverrideRules.parse("exp-nope=3s,exp-clean=4s,garbage,exp-stars=flat")
			expect(parsed["exp-nope"]).to.equal(nil)
			expect(parsed["exp-clean"]).to.equal(nil)
			expect(parsed["exp-stars"]).to.equal("flat")
		end)

		it("is empty for nil, a number or an empty string", function()
			expect(next(ExperimentOverrideRules.parse(nil))).to.equal(nil)
			expect(next(ExperimentOverrideRules.parse(42))).to.equal(nil)
			expect(next(ExperimentOverrideRules.parse(""))).to.equal(nil)
		end)
	end)
end
