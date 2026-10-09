local DeathSpectateRules = require(script.Parent.DeathSpectateRules)

return function()
	describe("candidates", function()
		it("lists living players other than the viewer, sorted", function()
			local public = {
				["3"] = {},
				["1"] = { dead = true },
				["2"] = {},
				["9"] = {},
			}
			local list = DeathSpectateRules.candidates(public, 9, "dead")
			expect(#list).to.equal(2)
			expect(list[1]).to.equal(2)
			expect(list[2]).to.equal(3)
		end)

		it("applies an optional filter", function()
			local public = { ["2"] = {}, ["3"] = { team = "red" } }
			local list = DeathSpectateRules.candidates(public, 9, "dead", function(userId)
				return userId == 3
			end)
			expect(#list).to.equal(1)
			expect(list[1]).to.equal(3)
		end)

		it("ignores keys that are not user ids", function()
			expect(#DeathSpectateRules.candidates({ abc = {} }, 9, "dead")).to.equal(0)
		end)
	end)

	describe("step", function()
		it("starts on the first candidate", function()
			expect(DeathSpectateRules.step({ 2, 5, 7 }, nil, 1)).to.equal(2)
		end)

		it("cycles forwards and backwards with wrap-around", function()
			expect(DeathSpectateRules.step({ 2, 5, 7 }, 5, 1)).to.equal(7)
			expect(DeathSpectateRules.step({ 2, 5, 7 }, 7, 1)).to.equal(2)
			expect(DeathSpectateRules.step({ 2, 5, 7 }, 2, -1)).to.equal(7)
		end)

		it("keeps the current target with a step of 0, or moves on when it is gone", function()
			expect(DeathSpectateRules.step({ 2, 5, 7 }, 5, 0)).to.equal(5)
			expect(DeathSpectateRules.step({ 2, 7 }, 5, 0)).to.equal(2)
		end)

		it("is nil with nobody to watch", function()
			expect(DeathSpectateRules.step({}, 5, 1)).to.equal(nil)
		end)
	end)
end
