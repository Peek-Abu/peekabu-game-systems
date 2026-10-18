local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftResultsUtils = require(script.Parent.ShiftResultsUtils)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)

local function input(crew, extra)
	local value = {
		outcome = "clockout",
		quota = 350,
		cleared = 380,
		bonus = 95,
		quotaMet = true,
		crew = crew,
		offered = 9,
		lookup = CargoRegistry.get,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function member(userId, name, stats)
	local value = { userId = userId, name = name, banked = 0, piles = 0, salvage = 0 }
	for key, item in stats or {} do
		value[key] = item
	end
	return value
end

local CREW = {
	member(1, "Ava", { banked = 120, piles = 3, salvage = 1, caught = 2, noise = 5, woke = 1 }),
	member(2, "Ben", { banked = 200, piles = 6, drops = 2, dropKind = "fishTank", dropValue = 70, noise = 9 }),
	member(3, "Cat", { noise = 0, woke = 0 }),
}

local function awardOf(results, title)
	for _, award in results.awards do
		if award.title == title then
			return award
		end
	end
	return nil
end

return function()
	describe("totals and crew", function()
		it("copies the shift's totals and sums the crew's", function()
			local results = ShiftResultsUtils.build(input(CREW))
			expect(results.outcome).to.equal("clockout")
			expect(results.cleared).to.equal(380)
			expect(results.bonus).to.equal(95)
			expect(results.piles).to.equal(9)
			expect(results.salvage).to.equal(1)
			expect(results.catches).to.equal(2)
			expect(results.offered).to.equal(9)
		end)

		it("carries the Gloom from piles, never more than the Gloom removed, absent reading 0", function()
			expect(ShiftResultsUtils.build(input(CREW, { dust = 300 })).dust).to.equal(300)
			expect(ShiftResultsUtils.build(input(CREW, { dust = 900 })).dust).to.equal(380)
			expect(ShiftResultsUtils.build(input(CREW)).dust).to.equal(0)
			expect(ShiftResultsUtils.bare("clockout", 350, true).dust).to.equal(0)
		end)

		it("counts Times caught as the whole crew's catches: one each for two members is 2", function()
			local results = ShiftResultsUtils.build(input({
				member(1, "Ava", { caught = 1 }),
				member(2, "Ben", { caught = 1 }),
			}))
			expect(results.catches).to.equal(2)
			expect(results.crew[1].caught).to.equal(1)
			expect(results.crew[2].caught).to.equal(1)
		end)

		it("lists the crew by amount banked, with userIds and catches", function()
			local results = ShiftResultsUtils.build(input(CREW))
			expect(results.crew[1].name).to.equal("Ben")
			expect(results.crew[1].userId).to.equal(2)
			expect(results.crew[1].caught).to.equal(0)
			expect(results.crew[2].caught).to.equal(2)
		end)

		it("carries each crew member's cargo items and overtime salvage (absent = 0) for the rank award", function()
			local results = ShiftResultsUtils.build(input({
				member(1, "Ava", { banked = 50, items = 6, overtimeSalvage = 2 }),
				member(2, "Ben"),
			}))
			expect(results.crew[1].items).to.equal(6)
			expect(results.crew[1].overtimeSalvage).to.equal(2)
			expect(results.crew[2].items).to.equal(0)
			expect(results.crew[2].overtimeSalvage).to.equal(0)
		end)

		it("builds a bare review for when the real one cannot be built", function()
			local results = ShiftResultsUtils.bare("clockout", 350, true)
			expect(results.cleared).to.equal(0)
			expect(results.offered).to.equal(0)
			expect(results.rating).to.equal("satisfactory")
			expect(#results.awards).to.equal(0)
		end)
	end)

	describe("rating", function()
		it("never rates a missed quota above NEEDS IMPROVEMENT", function()
			expect(ShiftResultsUtils.rating(false, 9, 9)).to.equal("needsImprovement")
			expect(ShiftResultsUtils.rating(false, 0, 0)).to.equal("needsImprovement")
		end)

		it("reads SATISFACTORY when no salvage was offered", function()
			expect(ShiftResultsUtils.rating(true, 0, 0)).to.equal("satisfactory")
		end)

		it("reads EXCEEDS at two of every three salvage loaded", function()
			expect(ShiftResultsUtils.rating(true, 6, 9)).to.equal("exceeds")
			expect(ShiftResultsUtils.rating(true, 2, 3)).to.equal("exceeds")
		end)

		it("reads SATISFACTORY just under the threshold", function()
			expect(ShiftResultsUtils.rating(true, 5, 9)).to.equal("satisfactory")
			expect(ShiftResultsUtils.rating(true, 1, 3)).to.equal("satisfactory")
		end)

		it("puts the rating on the review", function()
			expect(ShiftResultsUtils.build(input(CREW)).rating).to.equal("satisfactory")
			expect(ShiftResultsUtils.build(input(CREW, { quotaMet = false })).rating).to.equal("needsImprovement")
		end)
	end)

	describe("joke awards", function()
		it("makes the top hauler EMPLOYEE OF THE NIGHT", function()
			local award = awardOf(ShiftResultsUtils.build(input(CREW)), "EMPLOYEE OF THE NIGHT")
			expect(award.name).to.equal("Ben")
			expect(award.userId).to.equal(2)
			expect(award.detail).to.equal("hauled 200")
		end)

		it("gives MOST REHIRED to the most caught, in words", function()
			local award = awardOf(ShiftResultsUtils.build(input(CREW)), "MOST REHIRED")
			expect(award.name).to.equal("Ava")
			expect(award.detail).to.equal("caught twice")
			expect(ShiftResultsUtils.times(1)).to.equal("once")
			expect(ShiftResultsUtils.times(3)).to.equal("3 times")
		end)

		it("names the most valuable drop on BUTTERFINGERS", function()
			local award = awardOf(ShiftResultsUtils.build(input(CREW)), "BUTTERFINGERS")
			expect(award.name).to.equal("Ben")
			expect(award.detail).to.equal("dropped the fish tank")
		end)

		it("gives no BUTTERFINGERS when nobody dropped anything", function()
			local crew = { member(1, "Ava", { banked = 10 }) }
			expect(awardOf(ShiftResultsUtils.build(input(crew)), "BUTTERFINGERS")).to.equal(nil)
		end)

		it("gives QUIETEST FEET to the fewest times heard, then the fewest noises", function()
			local award = awardOf(ShiftResultsUtils.build(input(CREW)), "QUIETEST FEET")
			expect(award.name).to.equal("Cat")
			expect(award.detail).to.equal("never heard once")
		end)

		it("swaps in LOUDEST VACUUM when someone woke him three times", function()
			local crew = { member(1, "Ava", { woke = 4 }), member(2, "Ben", { woke = 0 }) }
			local results = ShiftResultsUtils.build(input(crew))
			expect(awardOf(results, "QUIETEST FEET")).to.equal(nil)
			local award = awardOf(results, "LOUDEST VACUUM")
			expect(award.name).to.equal("Ava")
			expect(award.detail).to.equal("woke the Manager 4 times")
		end)

		it("hands a tie to crew order (more banked, then name)", function()
			local crew =
				{ member(1, "Zed", { banked = 50, caught = 1 }), member(2, "Amy", { banked = 50, caught = 1 }) }
			local results = ShiftResultsUtils.build(input(crew))
			expect(awardOf(results, "EMPLOYEE OF THE NIGHT").name).to.equal("Amy")
			expect(awardOf(results, "MOST REHIRED").name).to.equal("Amy")
		end)

		it("gives no award for a stat nobody scored", function()
			local results = ShiftResultsUtils.build(input({ member(1, "Ava", {}) }))
			expect(awardOf(results, "EMPLOYEE OF THE NIGHT")).to.equal(nil)
			expect(awardOf(results, "MOST REHIRED")).to.equal(nil)
			expect(#results.awards).to.equal(1) -- QUIETEST FEET only
		end)
	end)
end
