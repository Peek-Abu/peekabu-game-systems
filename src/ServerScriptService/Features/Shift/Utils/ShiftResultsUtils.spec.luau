local ShiftResultsUtils = require(script.Parent.ShiftResultsUtils)

local function input(crew)
	return { outcome = "clockout", quota = 350, cleared = 380, bonus = 95, quotaMet = true, crew = crew }
end

local CREW = {
	{ userId = 1, name = "Ava", banked = 120, piles = 3, salvage = 1 },
	{ userId = 2, name = "Ben", banked = 200, piles = 6, salvage = 0 },
	{ userId = 3, name = "Cat", banked = 0, piles = 0, salvage = 0 },
}

return function()
	it("copies the shift's totals and sums the crew's", function()
		local results = ShiftResultsUtils.build(input(CREW))
		expect(results.outcome).to.equal("clockout")
		expect(results.cleared).to.equal(380)
		expect(results.quota).to.equal(350)
		expect(results.bonus).to.equal(95)
		expect(results.quotaMet).to.equal(true)
		expect(results.piles).to.equal(9)
		expect(results.salvage).to.equal(1)
	end)

	it("lists the crew by amount banked", function()
		local results = ShiftResultsUtils.build(input(CREW))
		expect(results.crew[1].name).to.equal("Ben")
		expect(results.crew[2].name).to.equal("Ava")
		expect(results.crew[3].name).to.equal("Cat")
	end)

	it("hands out an award per category to the leader", function()
		local results = ShiftResultsUtils.build(input(CREW))
		expect(#results.awards).to.equal(3)
		expect(results.awards[1].title).to.equal("Top Hauler")
		expect(results.awards[1].name).to.equal("Ben")
		expect(results.awards[2].title).to.equal("Dust Devil")
		expect(results.awards[2].name).to.equal("Ben")
		expect(results.awards[3].title).to.equal("Treasure Hunter")
		expect(results.awards[3].name).to.equal("Ava")
	end)

	it("gives no award when nobody scored in it", function()
		local results =
			ShiftResultsUtils.build(input({ { userId = 1, name = "Ava", banked = 0, piles = 0, salvage = 0 } }))
		expect(#results.awards).to.equal(0)
	end)

	it("breaks ties by name", function()
		local results = ShiftResultsUtils.build(input({
			{ userId = 1, name = "Zed", banked = 50, piles = 2, salvage = 0 },
			{ userId = 2, name = "Amy", banked = 50, piles = 2, salvage = 0 },
		}))
		expect(results.crew[1].name).to.equal("Amy")
		expect(results.awards[1].name).to.equal("Amy")
		expect(results.awards[2].name).to.equal("Amy")
	end)

	it("builds a bare review for when the real one cannot be built", function()
		local results = ShiftResultsUtils.bare("clockout", 350, true)
		expect(results.outcome).to.equal("clockout")
		expect(results.quota).to.equal(350)
		expect(results.quotaMet).to.equal(true)
		expect(results.cleared).to.equal(0)
		expect(#results.crew).to.equal(0)
		expect(#results.awards).to.equal(0)
	end)
end
