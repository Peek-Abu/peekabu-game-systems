local ShiftVoteRules = require(script.Parent.ShiftVoteRules)

return function()
	it("parses only the two choices", function()
		expect(ShiftVoteRules.parse("another")).to.equal("another")
		expect(ShiftVoteRules.parse("depot")).to.equal("depot")
		expect(ShiftVoteRules.parse("quit")).to.equal(nil)
		expect(ShiftVoteRules.parse(5)).to.equal(nil)
	end)

	it("tallies only players still present", function()
		local another, depot = ShiftVoteRules.tally({ [1] = "another", [2] = "depot", [9] = "depot" }, { 1, 2 })
		expect(another).to.equal(1)
		expect(depot).to.equal(1)
	end)

	describe("decide", function()
		it("waits while the vote is open and undecided", function()
			expect(ShiftVoteRules.decide({ [1] = "another" }, { 1, 2, 3 }, false)).to.equal(nil)
		end)

		it("lets a strict majority decide early", function()
			expect(ShiftVoteRules.decide({ [1] = "depot", [2] = "depot" }, { 1, 2, 3 }, false)).to.equal("depot")
		end)

		it("decides at once for a solo player", function()
			expect(ShiftVoteRules.decide({ [1] = "another" }, { 1 }, false)).to.equal("another")
		end)

		it("keeps working on a tie once everyone has voted", function()
			expect(ShiftVoteRules.decide({ [1] = "another", [2] = "depot" }, { 1, 2 }, false)).to.equal("another")
		end)

		it("times out to the larger side", function()
			expect(ShiftVoteRules.decide({ [1] = "depot" }, { 1, 2, 3 }, true)).to.equal("depot")
		end)

		it("times out to another with no votes, even in an empty server", function()
			expect(ShiftVoteRules.decide({}, { 1, 2 }, true)).to.equal("another")
			expect(ShiftVoteRules.decide({}, {}, true)).to.equal("another")
		end)
	end)
end
