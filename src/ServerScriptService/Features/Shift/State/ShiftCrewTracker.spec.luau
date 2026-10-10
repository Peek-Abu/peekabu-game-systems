local ShiftCrewTracker = require(script.Parent.ShiftCrewTracker)

local function same(a, b)
	if #a ~= #b then
		return false
	end
	for index, value in a do
		if b[index] ~= value then
			return false
		end
	end
	return true
end

return function()
	it("starts with nobody", function()
		local crew = ShiftCrewTracker.new()
		expect(#crew:present({ 1, 2 })).to.equal(0)
		expect(crew:startable({ 1, 2 }, 0)).to.equal(0)
		expect(crew:has(1)).to.equal(false)
	end)

	describe("join", function()
		it("makes the arriving party the crew", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 7, 8 }, { 7, 8, 9 })
			expect(crew:has(7)).to.equal(true)
			expect(crew:has(9)).to.equal(false)
			expect(same(crew:present({ 7, 8, 9 }), { 7, 8 })).to.equal(true)
		end)

		it("replaces a crew that has left the server", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 1 }, { 1 })
			crew:join({ 2 }, { 2 })
			expect(crew:has(1)).to.equal(false)
			expect(crew:has(2)).to.equal(true)
		end)

		it("adds a second party to a crew still here", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 1 }, { 1 })
			crew:join({ 2 }, { 1, 2 })
			expect(same(crew:present({ 1, 2 }), { 1, 2 })).to.equal(true)
		end)
	end)

	describe("add, remove and present", function()
		it("adds and removes one member, once", function()
			local crew = ShiftCrewTracker.new()
			expect(crew:add(4)).to.equal(true)
			expect(crew:add(4)).to.equal(false)
			expect(crew:remove(4)).to.equal(true)
			expect(crew:remove(4)).to.equal(false)
			expect(crew:has(4)).to.equal(false)
		end)

		it("counts only crew members who are here, once each, in UserId order", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 9, 3, 5 }, { 9, 3, 5 })
			expect(same(crew:present({ 5, 9, 4, 5 }), { 5, 9 })).to.equal(true)
			expect(crew:startable({ 5, 9, 4 }, 0)).to.equal(2)
		end)
	end)

	describe("leaving", function()
		it("holds the next shift while the crew is on its way home", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 1 }, { 1 })
			crew:leave(100, 40)
			expect(crew:isLeaving(139)).to.equal(true)
			expect(crew:startable({ 1 }, 139)).to.equal(0)
			expect(crew:expired(139)).to.equal(false)
		end)

		it("lets the crew work again once the window has passed, and says so once", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 1 }, { 1 })
			crew:leave(100, 40)
			expect(crew:isLeaving(140)).to.equal(false)
			expect(crew:startable({ 1 }, 140)).to.equal(1)
			expect(crew:expired(140)).to.equal(true)
			expect(crew:expired(141)).to.equal(false)
		end)

		it("never reports a window that was not opened", function()
			expect(ShiftCrewTracker.new():expired(1000)).to.equal(false)
		end)

		it("ends the window when a new party replaces the crew", function()
			local crew = ShiftCrewTracker.new()
			crew:join({ 1 }, { 1 })
			crew:leave(100, 40)
			crew:join({ 2 }, { 2 })
			expect(crew:isLeaving(110)).to.equal(false)
			expect(crew:startable({ 2 }, 110)).to.equal(1)
		end)
	end)

	it("clears everything", function()
		local crew = ShiftCrewTracker.new()
		crew:join({ 1, 2 }, { 1, 2 })
		crew:leave(0, 40)
		crew:clear()
		expect(crew:has(1)).to.equal(false)
		expect(crew:isLeaving(1)).to.equal(false)
	end)
end
