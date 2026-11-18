local ShiftNightViewModel = require(script.Parent.ShiftNightViewModel)

local function snapshot(extra)
	local value = {
		phase = "running",
		quota = 500,
		cleared = 300,
		runMode = "night",
		night = 4,
		week = 2,
		weekQuota = 1500,
		weekCleared = 600,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("of", function()
		it("reads a Night Shift snapshot", function()
			local night = ShiftNightViewModel.of(snapshot())
			expect(night).to.be.ok()
			expect(night.night).to.equal(4)
			expect(night.week).to.equal(2)
			expect(night.weekQuota).to.equal(1500)
			expect(night.weekCleared).to.equal(600)
			expect(night.runOver).to.equal(nil)
			expect(night.nightReached).to.equal(4)
		end)

		it("is nil on a quick shift, an old snapshot or no snapshot", function()
			expect(ShiftNightViewModel.of(nil)).to.equal(nil)
			expect(ShiftNightViewModel.of(snapshot({ runMode = "quick" }))).to.equal(nil)
			expect(ShiftNightViewModel.of(snapshot({ runMode = false }))).to.equal(nil)
			expect(ShiftNightViewModel.of(snapshot({ night = false }))).to.equal(nil)
		end)

		it("works the week out from the night when the snapshot has none, and reads no cleared as 0", function()
			local night = ShiftNightViewModel.of(snapshot({ night = 7, week = false, weekCleared = false }))
			expect(night.week).to.equal(3)
			expect(night.weekCleared).to.equal(0)
		end)

		it("keeps how the run ended and the night it reached", function()
			local night = ShiftNightViewModel.of(snapshot({ runOver = "fired", nightReached = 6, night = 6 }))
			expect(night.runOver).to.equal("fired")
			expect(night.nightReached).to.equal(6)
		end)
	end)

	it("names the night and the week in caps", function()
		expect(ShiftNightViewModel.nightTitle(4)).to.equal("NIGHT 4")
		expect(ShiftNightViewModel.weekTitle(2)).to.equal("WEEK 2")
	end)

	describe("weekLine", function()
		it("adds tonight's Gloom to the week while the night runs", function()
			local night = ShiftNightViewModel.of(snapshot())
			expect(ShiftNightViewModel.weekLine(night, 300, "running")).to.equal("This week: 900 / 1,500")
		end)

		it("does not count tonight twice once the night is over", function()
			local night = ShiftNightViewModel.of(snapshot({ weekCleared = 900 }))
			expect(ShiftNightViewModel.weekLine(night, 300, "results")).to.equal("This week: 900 / 1,500")
		end)

		it("shows nothing without a weekly quota", function()
			local night = ShiftNightViewModel.of(snapshot({ weekQuota = false }))
			expect(ShiftNightViewModel.weekLine(night, 300, "running")).to.equal(nil)
		end)
	end)

	describe("votes", function()
		it("reads Next night with the next night's number, and Clock out keeps your pay", function()
			local words = ShiftNightViewModel.votes(ShiftNightViewModel.of(snapshot()))
			expect(words.another).to.equal("NEXT: NIGHT 5")
			expect(words.depot).to.equal("CLOCK OUT")
			expect(string.find(words.footer, "keep your pay", 1, true)).to.be.ok()
			expect(string.find(words.footer, "Next night", 1, true)).to.be.ok()
		end)
	end)

	describe("ended", function()
		it("is nil while the run goes on", function()
			expect(ShiftNightViewModel.ended(ShiftNightViewModel.of(snapshot()))).to.equal(nil)
		end)

		it("says FIRED! for a missed weekly quota, with the night reached", function()
			local ended =
				ShiftNightViewModel.ended(ShiftNightViewModel.of(snapshot({ runOver = "fired", nightReached = 6 })))
			expect(ended.title).to.equal("FIRED!")
			expect(ended.good).to.equal(false)
			expect(string.find(ended.line, "night 6", 1, true)).to.be.ok()
		end)

		it("says OUT OF COATS when everyone ran out", function()
			local ended = ShiftNightViewModel.ended(ShiftNightViewModel.of(snapshot({ runOver = "wiped" })))
			expect(ended.title).to.equal("OUT OF COATS")
			expect(ended.good).to.equal(false)
			expect(string.find(ended.line, "night 4", 1, true)).to.be.ok()
		end)

		it("says CLOCKED OUT, a good ending, when the crew kept their pay", function()
			local ended =
				ShiftNightViewModel.ended(ShiftNightViewModel.of(snapshot({ runOver = "clockout", nightReached = 9 })))
			expect(ended.title).to.equal("CLOCKED OUT")
			expect(ended.good).to.equal(true)
			expect(string.find(ended.line, "night 9", 1, true)).to.be.ok()
		end)
	end)

	it("prints numbers with commas", function()
		expect(ShiftNightViewModel.commas(1500)).to.equal("1,500")
		expect(ShiftNightViewModel.commas(90)).to.equal("90")
		expect(ShiftNightViewModel.commas(1234567)).to.equal("1,234,567")
	end)
end
