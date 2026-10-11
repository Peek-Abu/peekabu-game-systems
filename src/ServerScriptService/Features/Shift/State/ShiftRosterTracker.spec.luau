local ShiftRosterTracker = require(script.Parent.ShiftRosterTracker)

local function find(list, userId)
	for _, entry in list do
		if entry.userId == userId then
			return entry
		end
	end
	return nil
end

return function()
	it("lists a player at zero once they are recorded", function()
		local roster = ShiftRosterTracker.new()
		roster:record(1, "Ava", {})
		local entry = find(roster:list(), 1)
		expect(entry.name).to.equal("Ava")
		expect(entry.banked).to.equal(0)
		expect(entry.piles).to.equal(0)
		expect(entry.salvage).to.equal(0)
	end)

	it("adds up what a player does", function()
		local roster = ShiftRosterTracker.new()
		roster:record(1, "Ava", { banked = 30, salvage = 1 })
		roster:record(1, "Ava", { banked = 20 })
		roster:record(1, "Ava", { piles = 1 })
		local entry = find(roster:list(), 1)
		expect(entry.banked).to.equal(50)
		expect(entry.salvage).to.equal(1)
		expect(entry.piles).to.equal(1)
	end)

	it("counts Harlow's catches, absent reading 0", function()
		local roster = ShiftRosterTracker.new()
		roster:record(1, "Ava", {})
		expect(find(roster:list(), 1).caught).to.equal(0)
		roster:record(1, "Ava", { caught = 1 })
		roster:record(1, "Ava", { caught = 1 })
		expect(find(roster:list(), 1).caught).to.equal(2)
	end)

	it("keeps the name it first saw", function()
		local roster = ShiftRosterTracker.new()
		roster:record(1, "Ava", {})
		roster:record(1, "Renamed", { piles = 1 })
		expect(find(roster:list(), 1).name).to.equal("Ava")
	end)

	it("keeps players independent", function()
		local roster = ShiftRosterTracker.new()
		roster:record(1, "Ava", { banked = 10 })
		roster:record(2, "Bo", { banked = 5 })
		expect(find(roster:list(), 1).banked).to.equal(10)
		expect(find(roster:list(), 2).banked).to.equal(5)
	end)

	it("hands out copies", function()
		local roster = ShiftRosterTracker.new()
		roster:record(1, "Ava", { banked = 10 })
		find(roster:list(), 1).banked = 999
		expect(find(roster:list(), 1).banked).to.equal(10)
	end)

	it("forgets everyone on clear", function()
		local roster = ShiftRosterTracker.new()
		roster:record(1, "Ava", { banked = 10 })
		roster:clear()
		expect(#roster:list()).to.equal(0)
	end)

	describe("review stats", function()
		it("counts noises made and times Harlow came to look", function()
			local roster = ShiftRosterTracker.new()
			roster:record(1, "Ava", { noise = 1 })
			roster:record(1, "Ava", { noise = 1, woke = 1 })
			local entry = roster:list()[1]
			expect(entry.noise).to.equal(2)
			expect(entry.woke).to.equal(1)
		end)

		it("counts drops and keeps the most valuable one", function()
			local roster = ShiftRosterTracker.new()
			roster:noteDrop(1, "Ava", "monitor", 30)
			roster:noteDrop(1, "Ava", "fishTank", 70)
			roster:noteDrop(1, "Ava", "rubbishBag", 10)
			local entry = roster:list()[1]
			expect(entry.drops).to.equal(3)
			expect(entry.dropKind).to.equal("fishTank")
			expect(entry.dropValue).to.equal(70)
		end)

		it("keeps the first of two drops worth the same", function()
			local roster = ShiftRosterTracker.new()
			roster:noteDrop(1, "Ava", "monitor", 30)
			roster:noteDrop(1, "Ava", "waterJug", 30)
			expect(roster:list()[1].dropKind).to.equal("monitor")
		end)

		it("starts a new member at zero for every stat", function()
			local roster = ShiftRosterTracker.new()
			roster:record(2, "Ben", {})
			local entry = roster:list()[1]
			expect(entry.drops).to.equal(0)
			expect(entry.noise).to.equal(0)
			expect(entry.woke).to.equal(0)
			expect(entry.dropKind).to.equal(nil)
		end)
	end)
end
