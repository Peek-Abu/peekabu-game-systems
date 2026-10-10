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
end
