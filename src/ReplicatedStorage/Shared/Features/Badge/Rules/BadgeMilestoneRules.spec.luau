local BadgeMilestoneRules = require(script.Parent.BadgeMilestoneRules)
local BadgeConstants = require(script.Parent.Parent.Data.BadgeConstants)

local function has(list, key)
	return table.find(list, key) ~= nil
end

return function()
	describe("BadgeMilestoneRules", function()
		it("lists a badge per key once, with every rank but the first", function()
			local seen = {}
			for _, entry in BadgeConstants.GAME do
				expect(seen[entry.key]).to.equal(nil)
				seen[entry.key] = true
			end
			for level = 2, 7 do
				expect(seen[`rank-{level}`]).to.equal(true)
			end
			expect(seen["rank-1"]).to.equal(nil)
		end)

		it("awards every rank reached, from Sweeper up", function()
			expect(#BadgeMilestoneRules.rankKeys(1)).to.equal(0)
			local keys = BadgeMilestoneRules.rankKeys(4)
			expect(#keys).to.equal(3)
			expect(has(keys, "rank-2")).to.equal(true)
			expect(has(keys, "rank-4")).to.equal(true)
			expect(has(keys, "rank-5")).to.equal(false)
		end)

		it("awards a finished shift's badges", function()
			local worked = { worked = true, quotaMet = false, crewExtracted = false, caught = false }
			local keys = BadgeMilestoneRules.shiftKeys(worked, 2)
			expect(#keys).to.equal(1)
			expect(keys[1]).to.equal("clocked-in")

			local sweep = { worked = true, quotaMet = true, crewExtracted = true, caught = false }
			keys = BadgeMilestoneRules.shiftKeys(sweep, BadgeConstants.SQUAD_SIZE)
			expect(has(keys, "clean-sweep")).to.equal(true)
			expect(has(keys, "night-shift-squad")).to.equal(true)

			local missed = { worked = true, quotaMet = false, crewExtracted = true, caught = false }
			expect(has(BadgeMilestoneRules.shiftKeys(missed, 1), "clean-sweep")).to.equal(false)
		end)

		it("awards nothing for a shift not worked", function()
			expect(#BadgeMilestoneRules.shiftKeys({ worked = false }, 4)).to.equal(0)
		end)

		it("awards the Locker badges by rarity", function()
			expect(#BadgeMilestoneRules.pullKeys("rare")).to.equal(0)
			local epic = BadgeMilestoneRules.pullKeys("epic")
			expect(#epic).to.equal(1)
			expect(epic[1]).to.equal("epic-pull")
			local legendary = BadgeMilestoneRules.pullKeys("legendary")
			expect(has(legendary, "epic-pull")).to.equal(true)
			expect(has(legendary, "legendary-pull")).to.equal(true)
			expect(has(BadgeMilestoneRules.pullKeys("odd"), "legendary-pull")).to.equal(true)
		end)

		it("awards New Look only for a skin that is not the default", function()
			expect(BadgeMilestoneRules.skinKey("default")).to.equal(nil)
			expect(BadgeMilestoneRules.skinKey("epic")).to.equal("new-look")
		end)
	end)
end
