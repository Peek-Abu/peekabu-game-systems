local OccupantEscapeRules = require(script.Parent.OccupantEscapeRules)

return function()
	describe("OccupantEscapeRules.lost", function()
		it("names the chase target he stopped tracking", function()
			local lost = OccupantEscapeRules.lost({ target = 5 }, {})
			expect(#lost).to.equal(1)
			expect(lost[1]).to.equal(5)
		end)

		it("names the hider he walked away from after a stare", function()
			local lost = OccupantEscapeRules.lost({ quarry = 7 }, {})
			expect(#lost).to.equal(1)
			expect(lost[1]).to.equal(7)
		end)

		it("is empty while he still tracks them as target or quarry", function()
			expect(#OccupantEscapeRules.lost({ target = 5 }, { target = 5 })).to.equal(0)
			-- A chase that turns into a stare at their spot has not lost them yet.
			expect(#OccupantEscapeRules.lost({ target = 5 }, { quarry = 5 })).to.equal(0)
			expect(#OccupantEscapeRules.lost({}, { target = 5 })).to.equal(0)
		end)

		it("names each lost player once", function()
			local lost = OccupantEscapeRules.lost({ target = 5, quarry = 5 }, {})
			expect(#lost).to.equal(1)
		end)
	end)
end
