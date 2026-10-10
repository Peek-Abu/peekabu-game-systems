local VacuumCanisterUtils = require(script.Parent.VacuumCanisterUtils)

return function()
	describe("add", function()
		it("fills one pile at a time", function()
			local fill, popped = VacuumCanisterUtils.add(0, 3)
			expect(fill).to.equal(1)
			expect(popped).to.equal(false)
			fill, popped = VacuumCanisterUtils.add(1, 3)
			expect(fill).to.equal(2)
			expect(popped).to.equal(false)
		end)

		it("pops a dust bag and empties when the third pile lands", function()
			local fill, popped = VacuumCanisterUtils.add(2, 3)
			expect(fill).to.equal(0)
			expect(popped).to.equal(true)
		end)
	end)

	describe("creditFor", function()
		local fills = { [1] = 2, [2] = 0, [3] = 0 }
		local function fillOf(id)
			return fills[id] or 0
		end

		it("credits the only channeler", function()
			expect(VacuumCanisterUtils.creditFor({ 1 }, fillOf)).to.equal(1)
		end)

		it("credits the emptiest canister, then the lowest UserId", function()
			expect(VacuumCanisterUtils.creditFor({ 1, 3, 2 }, fillOf)).to.equal(2)
		end)

		it("credits nobody when nobody was on it", function()
			expect(VacuumCanisterUtils.creditFor({}, fillOf)).to.equal(nil)
		end)
	end)
end
