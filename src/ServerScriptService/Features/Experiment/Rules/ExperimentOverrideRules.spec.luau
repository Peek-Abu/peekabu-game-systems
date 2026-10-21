local ExperimentOverrideRules = require(script.Parent.ExperimentOverrideRules)

return function()
	describe("parse", function()
		it("reads id=variant pairs, trimming spaces", function()
			local parsed = ExperimentOverrideRules.parse(" exp-tutorial=3beats , exp-friendskip = forced ")
			expect(parsed["exp-tutorial"]).to.equal("3beats")
			expect(parsed["exp-friendskip"]).to.equal("forced")
		end)

		it("drops unknown ids, unknown variants and malformed pairs", function()
			local parsed = ExperimentOverrideRules.parse("exp-nope=3s,exp-friendskip=4s,garbage,exp-stars=flat")
			expect(parsed["exp-nope"]).to.equal(nil)
			expect(parsed["exp-friendskip"]).to.equal(nil)
			expect(parsed["exp-stars"]).to.equal("flat")
		end)

		it("is empty for nil, a number or an empty string", function()
			expect(next(ExperimentOverrideRules.parse(nil))).to.equal(nil)
			expect(next(ExperimentOverrideRules.parse(42))).to.equal(nil)
			expect(next(ExperimentOverrideRules.parse(""))).to.equal(nil)
		end)
	end)
end
