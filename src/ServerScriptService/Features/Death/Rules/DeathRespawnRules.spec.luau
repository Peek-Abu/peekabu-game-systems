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

	describe("keepsPlace", function()
		it("keeps only a character marked true (a swap where it stands) off the spawn point", function()
			expect(DeathRespawnRules.keepsPlace(true)).to.equal(true)
			expect(DeathRespawnRules.keepsPlace(nil)).to.equal(false)
			expect(DeathRespawnRules.keepsPlace(false)).to.equal(false)
			expect(DeathRespawnRules.keepsPlace("yes")).to.equal(false)
		end)
	end)
	describe("watches", function()
		it("watches the player's live character, in the world", function()
			expect(DeathRespawnRules.watches(true, true)).to.equal(true)
		end)

		it(
			"skips a character already replaced or removed (a rebuild right after a spawn): no wait, no warning",
			function()
				expect(DeathRespawnRules.watches(false, true)).to.equal(false)
				expect(DeathRespawnRules.watches(true, false)).to.equal(false)
				expect(DeathRespawnRules.watches(false, false)).to.equal(false)
			end
		)
	end)
end
