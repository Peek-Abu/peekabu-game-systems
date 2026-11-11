local OccupantRosterRules = require(script.Parent.OccupantRosterRules)

local function roster(entries, budget)
	return { entries = entries, budget = budget }
end

return function()
	describe("pick", function()
		it("picks the only kind of a one-kind roster, whatever the seed", function()
			for seed = 1, 20 do
				local kinds = OccupantRosterRules.pick(roster({ { kind = "bramble", weight = 1 } }, 1), seed)
				expect(#kinds).to.equal(1)
				expect(kinds[1]).to.equal("bramble")
			end
		end)

		it("is the same for the same seed", function()
			local both = roster({ { kind = "harlow", weight = 1 }, { kind = "bramble", weight = 1 } }, 1)
			for seed = 1, 20 do
				expect(OccupantRosterRules.pick(both, seed)[1]).to.equal(OccupantRosterRules.pick(both, seed)[1])
			end
		end)

		it("follows the weights over many seeds", function()
			local skewed = roster({ { kind = "harlow", weight = 3 }, { kind = "bramble", weight = 1 } }, 1)
			local harlow = 0
			for seed = 1, 400 do
				if OccupantRosterRules.pick(skewed, seed)[1] == "harlow" then
					harlow += 1
				end
			end
			expect(harlow > 240).to.equal(true)
			expect(harlow < 360).to.equal(true)
		end)

		it("never picks a kind with no weight", function()
			local one = roster({ { kind = "harlow", weight = 0 }, { kind = "bramble", weight = 1 } }, 1)
			for seed = 1, 50 do
				expect(OccupantRosterRules.pick(one, seed)[1]).to.equal("bramble")
			end
		end)

		it("picks up to the budget, never the same kind twice", function()
			local both = roster({ { kind = "harlow", weight = 1 }, { kind = "bramble", weight = 1 } }, 2)
			local kinds = OccupantRosterRules.pick(both, 7)
			expect(#kinds).to.equal(2)
			expect(kinds[1] ~= kinds[2]).to.equal(true)
		end)

		it("picks no more kinds than the roster has", function()
			local kinds = OccupantRosterRules.pick(roster({ { kind = "harlow", weight = 1 } }, 3), 1)
			expect(#kinds).to.equal(1)
		end)

		it("picks nothing from an empty roster or a zero budget", function()
			expect(#OccupantRosterRules.pick(roster({}, 1), 1)).to.equal(0)
			expect(#OccupantRosterRules.pick(roster({ { kind = "harlow", weight = 1 } }, 0), 1)).to.equal(0)
		end)
	end)

	describe("kindFor", function()
		it("runs Harlow in the Office and Bramble in the School", function()
			for seed = 1, 10 do
				expect(OccupantRosterRules.kindFor("office", seed)).to.equal("harlow")
				expect(OccupantRosterRules.kindFor("school", seed)).to.equal("bramble")
			end
		end)

		it("falls back to Harlow on a map with no roster", function()
			expect(OccupantRosterRules.kindFor("moon", 1)).to.equal("harlow")
		end)
	end)

	describe("valid", function()
		it("accepts the registered rosters", function()
			expect(OccupantRosterRules.valid(roster({ { kind = "harlow", weight = 1 } }, 1))).to.equal(true)
		end)

		it("refuses an unknown kind, a weight of 0 or less, a budget below 1 or a repeated kind", function()
			expect(OccupantRosterRules.valid(roster({ { kind = "ghost", weight = 1 } }, 1))).to.equal(false)
			expect(OccupantRosterRules.valid(roster({ { kind = "harlow", weight = 0 } }, 1))).to.equal(false)
			expect(OccupantRosterRules.valid(roster({ { kind = "harlow", weight = 1 } }, 0))).to.equal(false)
			expect(
				OccupantRosterRules.valid(
					roster({ { kind = "harlow", weight = 1 }, { kind = "harlow", weight = 2 } }, 1)
				)
			).to.equal(false)
		end)

		it("holds for every registered roster", function()
			expect(OccupantRosterRules.allValid()).to.equal(true)
		end)
	end)
end
