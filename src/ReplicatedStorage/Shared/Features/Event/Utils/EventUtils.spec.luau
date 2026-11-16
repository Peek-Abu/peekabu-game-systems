local EventUtils = require(script.Parent.EventUtils)

return function()
	local DAY = 86400
	local function event(id, starts, ends)
		return { id = id, starts = starts, ends = ends }
	end
	local A = event("a", 1000, 2000)
	local B = event("b", 5000, 9000)
	local EVENTS = { A, B }

	describe("live", function()
		it("is the event whose dates hold now, else nil", function()
			expect(EventUtils.live(EVENTS, 999, nil)).to.equal(nil)
			expect(EventUtils.live(EVENTS, 1000, nil)).to.equal(A)
			expect(EventUtils.live(EVENTS, 1999, nil)).to.equal(A)
			expect(EventUtils.live(EVENTS, 2000, nil)).to.equal(nil)
			expect(EventUtils.live(EVENTS, 6000, nil)).to.equal(B)
		end)

		it("is the previewed event at any time (admin preview), and ignores an unknown preview", function()
			expect(EventUtils.live(EVENTS, 0, "b")).to.equal(B)
			expect(EventUtils.live(EVENTS, 1500, "b")).to.equal(B)
			expect(EventUtils.live(EVENTS, 1500, "zzz")).to.equal(A)
			expect(EventUtils.live(EVENTS, 0, "")).to.equal(nil)
		end)
	end)

	describe("daysLeft", function()
		it("counts a started day as a whole day, and never goes below 0", function()
			local e = event("e", 0, 10 * DAY)
			expect(EventUtils.daysLeft(e, 0)).to.equal(10)
			expect(EventUtils.daysLeft(e, 1)).to.equal(10)
			expect(EventUtils.daysLeft(e, 9 * DAY + 5)).to.equal(1)
			expect(EventUtils.daysLeft(e, 10 * DAY)).to.equal(0)
			expect(EventUtils.daysLeft(e, 20 * DAY)).to.equal(0)
		end)

		it("gives at least 1 to a previewed event outside its dates", function()
			local e = event("e", 0, DAY)
			expect(EventUtils.daysLeft(e, 5 * DAY, true)).to.equal(1)
		end)
	end)

	describe("day", function()
		it("numbers UTC days, shifted by the offset hours", function()
			expect(EventUtils.day(0, 0)).to.equal(0)
			expect(EventUtils.day(DAY - 1, 0)).to.equal(0)
			expect(EventUtils.day(DAY, 0)).to.equal(1)
			-- A -5 h offset: 03:00 UTC on day 1 is still day 0.
			expect(EventUtils.day(DAY + 3 * 3600, -5)).to.equal(0)
		end)
	end)
end
