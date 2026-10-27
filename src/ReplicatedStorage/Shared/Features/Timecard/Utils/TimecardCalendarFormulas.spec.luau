local TimecardCalendarFormulas = require(script.Parent.TimecardCalendarFormulas)

-- Monday 26 Oct 2026 00:00 UTC. The timecard's week runs Monday 00:00 UTC to Sunday 23:59:59 UTC, so every
-- expectation below is pinned to these real timestamps rather than to a clock.
local MONDAY = 1792972800
local DAY = 86400
local WEEK = 7 * DAY

local function card(punched, extra)
	local value = { week = MONDAY, punched = punched, weeks = 0 }
	for key, field in extra or {} do
		value[key] = field
	end
	return value
end

return function()
	describe("calendar", function()
		it("numbers the week Monday = 1 through Sunday = 7", function()
			expect(TimecardCalendarFormulas.dayOfWeek(MONDAY)).to.equal(1)
			expect(TimecardCalendarFormulas.dayOfWeek(MONDAY + DAY)).to.equal(2)
			expect(TimecardCalendarFormulas.dayOfWeek(MONDAY + 3 * DAY)).to.equal(4)
			expect(TimecardCalendarFormulas.dayOfWeek(MONDAY + 6 * DAY)).to.equal(7)
			-- The last second of Sunday is still the same week's Sunday.
			expect(TimecardCalendarFormulas.dayOfWeek(MONDAY + WEEK - 1)).to.equal(7)
		end)

		it("puts every moment of a week on that week's Monday", function()
			expect(TimecardCalendarFormulas.weekStart(MONDAY)).to.equal(MONDAY)
			expect(TimecardCalendarFormulas.weekStart(MONDAY + 3 * DAY + 1234)).to.equal(MONDAY)
			expect(TimecardCalendarFormulas.weekStart(MONDAY + WEEK - 1)).to.equal(MONDAY)
			-- Sunday's last second belongs to the week that started six days earlier, not to the next one.
			expect(TimecardCalendarFormulas.weekStart(MONDAY - 1)).to.equal(MONDAY - WEEK)
			expect(TimecardCalendarFormulas.weekStart(MONDAY + WEEK)).to.equal(MONDAY + WEEK)
		end)

		it("keys a week by its Monday's UTC date", function()
			expect(TimecardCalendarFormulas.weekKey(MONDAY)).to.equal("2026-10-26")
			expect(TimecardCalendarFormulas.weekKey(MONDAY + 6 * DAY + 3599)).to.equal("2026-10-26")
			expect(TimecardCalendarFormulas.weekKey(MONDAY - 1)).to.equal("2026-10-19")
			expect(TimecardCalendarFormulas.weekKey(MONDAY + WEEK)).to.equal("2026-11-02")
		end)
	end)

	describe("roll", function()
		it("leaves a card that is already on this week alone", function()
			local current = card({ 1, 2, 4 }, { weeks = 2 })
			expect(TimecardCalendarFormulas.roll(current, MONDAY + 4 * DAY)).to.equal(current)
		end)

		it("starts a fresh card on Monday and keeps a completed week's run", function()
			local last = card({ 1, 2, 3, 4, 5 }, { weeks = 3 })
			local rolled = TimecardCalendarFormulas.roll(last, MONDAY + WEEK)
			expect(rolled.week).to.equal(MONDAY + WEEK)
			expect(#rolled.punched).to.equal(0)
			expect(rolled.weeks).to.equal(3)
		end)

		it("breaks the run when the week that passed was not completed", function()
			local missed = card({ 1, 2, 3 }, { weeks = 2 })
			expect(TimecardCalendarFormulas.roll(missed, MONDAY + WEEK).weeks).to.equal(0)
		end)

		it("breaks the run when more than one week passed, even a completed one", function()
			local complete = card({ 1, 2, 3, 4, 6 }, { weeks = 1 })
			expect(TimecardCalendarFormulas.roll(complete, MONDAY + 2 * WEEK).weeks).to.equal(0)
		end)
	end)

	describe("punch", function()
		it("records the day and reports the punch count", function()
			local result = TimecardCalendarFormulas.punch(card({}), MONDAY + DAY)
			expect(result.outcome).to.equal("punched")
			expect(result.count).to.equal(1)
			expect(result.card.punched[1]).to.equal(2)
			expect(result.card.week).to.equal(MONDAY)
		end)

		it("punches once a day", function()
			local first = TimecardCalendarFormulas.punch(card({}), MONDAY + 8 * 3600)
			local second = TimecardCalendarFormulas.punch(first.card, MONDAY + 9 * 3600)
			expect(second.outcome).to.equal("already")
			expect(second.count).to.equal(1)
			expect(#second.card.punched).to.equal(1)
			expect(second.card).to.equal(first.card)
		end)

		it("does not reset the week on a missed day", function()
			local monday = TimecardCalendarFormulas.punch(card({}), MONDAY)
			local thursday = TimecardCalendarFormulas.punch(monday.card, MONDAY + 3 * DAY)
			expect(thursday.outcome).to.equal("punched")
			expect(thursday.count).to.equal(2)
			expect(#thursday.card.punched).to.equal(2)
			expect(thursday.card.punched[1]).to.equal(1)
			expect(thursday.card.punched[2]).to.equal(4)
			expect(TimecardCalendarFormulas.complete(thursday.card)).to.equal(false)
		end)

		it("keeps the days in order however they are punched", function()
			local friday = TimecardCalendarFormulas.punch(card({}), MONDAY + 4 * DAY)
			local tuesday = TimecardCalendarFormulas.punch(friday.card, MONDAY + DAY)
			expect(tuesday.card.punched[1]).to.equal(2)
			expect(tuesday.card.punched[2]).to.equal(5)
		end)

		it("leaves the card it was given untouched", function()
			local before = card({ 1, 2 })
			local result = TimecardCalendarFormulas.punch(before, MONDAY + 4 * DAY)
			expect(#before.punched).to.equal(2)
			expect(result.card ~= before).to.equal(true)
			expect(#result.card.punched).to.equal(3)
		end)

		it("completes on any five of the seven days", function()
			local sun = TimecardCalendarFormulas.punch(card({}), MONDAY + 6 * DAY)
			local tue = TimecardCalendarFormulas.punch(sun.card, MONDAY + DAY)
			local thu = TimecardCalendarFormulas.punch(tue.card, MONDAY + 3 * DAY)
			local mon = TimecardCalendarFormulas.punch(thu.card, MONDAY)
			expect(TimecardCalendarFormulas.complete(mon.card)).to.equal(false)
			expect(mon.card.weeks).to.equal(0)
			local sat = TimecardCalendarFormulas.punch(mon.card, MONDAY + 5 * DAY)
			expect(TimecardCalendarFormulas.complete(sat.card)).to.equal(true)
			expect(sat.card.weeks).to.equal(1)
			expect(sat.paycheck).to.equal(false)
		end)

		it("pays the third punch a key and the fifth the stars, and nothing else", function()
			local milestones = {}
			local current = card({})
			local days = { 1, 2, 3, 5, 6, 7 }
			for index, day in days do
				local result = TimecardCalendarFormulas.punch(current, MONDAY + (day - 1) * DAY)
				milestones[index] = result.milestone
				current = result.card
			end
			expect(milestones[1]).to.equal(nil)
			expect(milestones[2]).to.equal(nil)
			expect(milestones[3]).to.equal("key")
			expect(milestones[4]).to.equal(nil)
			expect(milestones[5]).to.equal("stars")
			expect(milestones[6]).to.equal(nil)
		end)

		it("pays a paycheque on every fourth consecutive completed week", function()
			local third = card({ 1, 2, 3, 4 }, { weeks = 3 })
			local result = TimecardCalendarFormulas.punch(third, MONDAY + 4 * DAY)
			expect(result.paycheck).to.equal(true)
			expect(result.card.weeks).to.equal(4)

			local steady = card({ 1, 2, 3, 4 }, { weeks = 4 })
			expect(TimecardCalendarFormulas.punch(steady, MONDAY + 4 * DAY).paycheck).to.equal(false)

			local eighth = card({ 1, 2, 3, 4 }, { weeks = 7 })
			local paid = TimecardCalendarFormulas.punch(eighth, MONDAY + 4 * DAY)
			expect(paid.paycheck).to.equal(true)
			expect(paid.card.weeks).to.equal(8)
		end)

		it("rolls over to the new week before punching it", function()
			local finished = card({ 1, 2, 3, 4, 5 }, { weeks = 1 })
			local result = TimecardCalendarFormulas.punch(finished, MONDAY + WEEK + 2 * 3600)
			expect(result.card.week).to.equal(MONDAY + WEEK)
			expect(result.card.punched[1]).to.equal(1)
			expect(#result.card.punched).to.equal(1)
			expect(result.card.weeks).to.equal(1)
			expect(result.count).to.equal(1)
		end)
	end)
end
