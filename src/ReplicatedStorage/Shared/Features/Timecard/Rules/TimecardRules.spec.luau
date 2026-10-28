local TimecardRules = require(script.Parent.TimecardRules)
local TimecardConstants = require(script.Parent.Parent.Data.TimecardConstants)

-- Monday 26 Oct 2026 00:00 UTC, the same pinned week the calendar spec uses.
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
	describe("the stored card", function()
		it("rejects infinite values and stamps that are not UTC Mondays", function()
			expect(TimecardRules.validate(card({}, { week = math.huge }))).to.equal(false)
			expect(TimecardRules.validate(card({}, { weeks = math.huge }))).to.equal(false)
			expect(TimecardRules.validate(card({}, { week = MONDAY + 1 }))).to.equal(false)
		end)
		it("accepts a card the calendar writes", function()
			expect(TimecardRules.validate(card({ 1, 2, 4 }, { weeks = 2 }))).to.equal(true)
			expect(TimecardRules.validate(card({}))).to.equal(true)
			expect(TimecardRules.validate({ week = 0, punched = {}, weeks = 0 })).to.equal(true)
			expect(TimecardRules.validate(card({ 1, 2, 3, 4, 5 }))).to.equal(true)
		end)

		it("refuses a week stamp that is not a whole, non-negative timestamp", function()
			expect(TimecardRules.validate(card({}, { week = -1 }))).to.equal(false)
			expect(TimecardRules.validate(card({}, { week = 1792972800.5 }))).to.equal(false)
			expect(TimecardRules.validate(card({}, { weeks = -1 }))).to.equal(false)
			expect(TimecardRules.validate(card({}, { weeks = 1.5 }))).to.equal(false)
		end)

		it("refuses a day outside the week", function()
			expect(TimecardRules.validate(card({ 0 }))).to.equal(false)
			expect(TimecardRules.validate(card({ 8 }))).to.equal(false)
			expect(TimecardRules.validate(card({ 2 }))).to.equal(true)
			expect(TimecardRules.validate(card({ 2.5 }))).to.equal(false)
			expect(TimecardRules.validate(card({ 7 }))).to.equal(true)
		end)

		it("refuses sparse and oversized punch lists", function()
			expect(TimecardRules.validate(card({ [2] = 2 }))).to.equal(false)
			expect(TimecardRules.validate(card({ 1, 2, 3, 4, 5, 6, 7, 8 }))).to.equal(false)
		end)
		it("refuses days that repeat or fall out of order", function()
			expect(TimecardRules.validate(card({ 2, 2 }))).to.equal(false)
			expect(TimecardRules.validate(card({ 3, 1 }))).to.equal(false)
			-- The calendar always sorts, so a correct card is ascending; order is what the validator checks.
			expect(TimecardRules.validate(card({ 1, 3, 5 }))).to.equal(true)
		end)

		it("refuses punches on a card that has no week yet", function()
			expect(TimecardRules.validate({ week = 0, punched = { 1 }, weeks = 0 })).to.equal(false)
		end)
	end)

	describe("where the card stands", function()
		it("reads a fresh card on Monday as punchable, three punches from the key", function()
			local status = TimecardRules.status(card({}), MONDAY)
			expect(status.week).to.equal(MONDAY)
			expect(status.weekKey).to.equal("2026-10-26")
			expect(status.today).to.equal(1)
			expect(status.count).to.equal(0)
			expect(status.complete).to.equal(false)
			expect(status.canPunch).to.equal(true)
			expect(status.nextMilestone).to.equal("key")
			expect(status.punchesToMilestone).to.equal(3)
			expect(status.weeksToPaycheque).to.equal(TimecardConstants.PAYCHEQUE_WEEKS)
		end)

		it("counts down to the stars once the key is paid", function()
			local status = TimecardRules.status(card({ 1, 2, 3 }), MONDAY + 3 * DAY)
			expect(status.count).to.equal(3)
			expect(status.nextMilestone).to.equal("stars")
			expect(status.punchesToMilestone).to.equal(2)
			expect(status.canPunch).to.equal(true)
		end)

		it("has nothing left to pay once the card is full", function()
			local status = TimecardRules.status(card({ 1, 2, 3, 4, 5 }, { weeks = 1 }), MONDAY + 5 * DAY)
			expect(status.complete).to.equal(true)
			expect(status.nextMilestone).to.equal(nil)
			expect(status.punchesToMilestone).to.equal(nil)
			-- A player may still punch the sixth and seventh day; it just pays nothing.
			expect(status.canPunch).to.equal(true)
		end)

		it("refuses a second punch on a day already on the card", function()
			local status = TimecardRules.status(card({ 1, 3 }), MONDAY + 2 * 3600)
			expect(status.canPunch).to.equal(false)
			expect(TimecardRules.canPunch(card({ 1, 3 }), MONDAY + 2 * 3600)).to.equal(false)
			expect(TimecardRules.canPunch(card({ 1, 3 }), MONDAY + DAY)).to.equal(true)
		end)

		it("counts the filled weeks left before the paycheque", function()
			expect(TimecardRules.status(card({}, { weeks = 3 }), MONDAY).weeksToPaycheque).to.equal(1)
			-- Four filled weeks already banked: the next paycheque is four more away, not due now.
			expect(TimecardRules.status(card({}, { weeks = 4 }), MONDAY).weeksToPaycheque).to.equal(4)
			expect(TimecardRules.status(card({}, { weeks = 7 }), MONDAY).weeksToPaycheque).to.equal(1)
		end)

		it("reads a stale card as the current week, without touching the stored one", function()
			local stale = card({ 1, 2, 3, 4, 5 }, { week = MONDAY - WEEK, weeks = 1 })
			local status = TimecardRules.status(stale, MONDAY)
			expect(status.week).to.equal(MONDAY)
			expect(status.count).to.equal(0)
			expect(status.complete).to.equal(false)
			expect(status.weeks).to.equal(1)
			-- The stored card is untouched: rolling is the server's write, not a read's side effect.
			expect(stale.week).to.equal(MONDAY - WEEK)
			expect(#stale.punched).to.equal(5)
		end)

		it("reads a card left two weeks ago as a fresh run", function()
			local stale = card({ 1, 2, 3, 4, 5 }, { week = MONDAY - 2 * WEEK, weeks = 4 })
			local status = TimecardRules.status(stale, MONDAY)
			expect(status.weeks).to.equal(0)
			expect(status.weeksToPaycheque).to.equal(TimecardConstants.PAYCHEQUE_WEEKS)
		end)
	end)
end
