local ShiftNightViewModel = require(script.Parent.ShiftNightViewModel)

local function snapshot(extra)
	local value = {
		phase = "running",
		quota = 500,
		cleared = 300,
		runMode = "night",
		night = 4,
		week = 2,
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
			expect(night.weekBonus).to.equal(nil)
			expect(night.runOver).to.equal(nil)
			expect(night.nightReached).to.equal(4)
		end)

		it("is nil on a quick shift, an old snapshot or no snapshot", function()
			expect(ShiftNightViewModel.of(nil)).to.equal(nil)
			expect(ShiftNightViewModel.of(snapshot({ runMode = "quick" }))).to.equal(nil)
			expect(ShiftNightViewModel.of(snapshot({ runMode = false }))).to.equal(nil)
			expect(ShiftNightViewModel.of(snapshot({ night = false }))).to.equal(nil)
		end)

		it("works the week out from the night when the snapshot has none", function()
			local night = ShiftNightViewModel.of(snapshot({ night = 7, week = false }))
			expect(night.week).to.equal(2)
		end)

		it("reads the week report's bonus", function()
			expect(ShiftNightViewModel.of(snapshot({ weekBonus = 150 })).weekBonus).to.equal(150)
			expect(ShiftNightViewModel.of(snapshot({ weekBonus = "x" })).weekBonus).to.equal(nil)
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

	describe("weekReport", function()
		it("is nil on a night that did not end a week", function()
			expect(ShiftNightViewModel.weekReport(ShiftNightViewModel.of(snapshot()))).to.equal(nil)
		end)

		it("reports the week done, the nights survived and the bonus", function()
			local report = ShiftNightViewModel.weekReport(
				ShiftNightViewModel.of(snapshot({ night = 10, week = 2, weekBonus = 300 }))
			)
			expect(report.title).to.equal("WEEK 2 DONE!")
			expect(report.good).to.equal(true)
			expect(string.find(report.line, "10 nights", 1, true)).to.be.ok()
			expect(string.find(report.line, "+300", 1, true)).to.be.ok()
		end)

		it("gives way to a run that is over", function()
			local over = ShiftNightViewModel.of(snapshot({ weekBonus = 150, runOver = "clockout" }))
			expect(ShiftNightViewModel.weekReport(over)).to.equal(nil)
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

		it("says FIRED! for a missed night goal, with the night reached", function()
			local ended =
				ShiftNightViewModel.ended(ShiftNightViewModel.of(snapshot({ runOver = "fired", nightReached = 6 })))
			expect(ended.title).to.equal("FIRED!")
			expect(ended.good).to.equal(false)
			expect(string.find(ended.line, "tonight's goal", 1, true)).to.be.ok()
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
