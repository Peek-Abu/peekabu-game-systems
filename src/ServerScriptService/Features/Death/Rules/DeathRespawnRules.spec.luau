local DeathRespawnRules = require(script.Parent.DeathRespawnRules)

return function()
	describe("respawns", function()
		it("auto respawns a player who is not held", function()
			expect(DeathRespawnRules.respawns("auto", false)).to.equal(true)
		end)

		it("auto leaves a held player down", function()
			expect(DeathRespawnRules.respawns("auto", true)).to.equal(false)
		end)

		it("manual never respawns on its own, held or not", function()
			expect(DeathRespawnRules.respawns("manual", false)).to.equal(false)
			expect(DeathRespawnRules.respawns("manual", true)).to.equal(false)
		end)
	end)
end
