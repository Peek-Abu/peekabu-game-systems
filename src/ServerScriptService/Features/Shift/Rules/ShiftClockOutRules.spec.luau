local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftClockOutRules = require(script.Parent.ShiftClockOutRules)
local ShiftPhaseRules = require(script.Parent.ShiftPhaseRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local LEAVE = ShiftConstants.TRUCK_LEAVES_SECONDS

-- A shift that started running at 100 and ends at 520.
local function running()
	return ShiftPhaseRules.follow(
		ShiftPhaseRules.initial(350, "B"),
		{ phase = "running", round = 1, endsAt = 520 },
		100
	)
end

-- `running()` with these crew members punched.
local function punched(ids)
	local state = running()
	for _, userId in ids do
		state = ShiftClockOutRules.punch(state, userId)
	end
	return state
end

return function()
	describe("stillIn", function()
		it("is the crew minus whoever is out (caught and spectating), sorted, each once", function()
			local ids = ShiftClockOutRules.stillIn({ 30, 10, 20, 10 }, { 20 })
			expect(#ids).to.equal(2)
			expect(ids[1]).to.equal(10)
			expect(ids[2]).to.equal(30)
		end)

		it("is empty when nobody is left", function()
			expect(#ShiftClockOutRules.stillIn({}, {})).to.equal(0)
			expect(#ShiftClockOutRules.stillIn({ 1 }, { 1 })).to.equal(0)
		end)
	end)

	describe("punch", function()
		it("records a crew member's card while the shift runs", function()
			local state = ShiftClockOutRules.punch(running(), 7)
			expect(ShiftClockOutRules.isPunched(state, 7)).to.equal(true)
			expect(ShiftClockOutRules.isPunched(state, 8)).to.equal(false)
		end)

		it("refuses a second punch by the same member", function()
			expect(ShiftClockOutRules.punch(punched({ 7 }), 7)).to.equal(nil)
		end)

		it("refuses outside a running shift", function()
			expect(ShiftClockOutRules.punch(ShiftPhaseRules.initial(350, "B"), 7)).to.equal(nil)
		end)

		it("never changes the state it was given", function()
			local before = running()
			ShiftClockOutRules.punch(before, 7)
			expect(ShiftClockOutRules.isPunched(before, 7)).to.equal(false)
		end)

		it("starts every run with nobody punched", function()
			local after = ShiftPhaseRules.follow(punched({ 1 }), { phase = "results", round = 1 }, 300)
			local again = ShiftPhaseRules.follow(after, { phase = "running", round = 2, endsAt = 900 }, 400)
			expect(ShiftClockOutRules.isPunched(again, 1)).to.equal(false)
		end)
	end)

	describe("tally", function()
		it("counts only the punched members still in", function()
			local count, total = ShiftClockOutRules.tally(punched({ 1, 2 }), { 1, 3, 4 })
			expect(count).to.equal(1)
			expect(total).to.equal(3)
		end)
	end)

	describe("verdict", function()
		it("leaves at once when everyone still in has punched (solo included)", function()
			expect(ShiftClockOutRules.verdict(1, 1)).to.equal("leave")
			expect(ShiftClockOutRules.verdict(3, 3)).to.equal("leave")
		end)

		it("starts the truck countdown once half or more have punched", function()
			expect(ShiftClockOutRules.verdict(1, 2)).to.equal("countdown")
			expect(ShiftClockOutRules.verdict(2, 3)).to.equal("countdown")
			expect(ShiftClockOutRules.verdict(2, 4)).to.equal("countdown")
			expect(ShiftClockOutRules.verdict(3, 4)).to.equal("countdown")
		end)

		it("waits below half", function()
			expect(ShiftClockOutRules.verdict(1, 3)).to.equal("none")
			expect(ShiftClockOutRules.verdict(1, 4)).to.equal("none")
			expect(ShiftClockOutRules.verdict(0, 2)).to.equal("none")
		end)

		it("waits with nobody still in", function()
			expect(ShiftClockOutRules.verdict(0, 0)).to.equal("none")
		end)
	end)

	describe("settle", function()
		it("records how many are still in, and nothing else, below half", function()
			local state = ShiftClockOutRules.settle(punched({ 1 }), { 1, 2, 3 }, 200)
			expect(state.crewIn).to.equal(3)
			expect(state.sub).to.equal("normal")
			expect(state.clockOutAt).to.equal(nil)
		end)

		it("is nil when nothing changed", function()
			local state = ShiftClockOutRules.settle(punched({ 1 }), { 1, 2, 3 }, 200)
			expect(ShiftClockOutRules.settle(state, { 1, 2, 3 }, 201)).to.equal(nil)
		end)

		it("starts the truck countdown at half", function()
			local state = ShiftClockOutRules.settle(punched({ 1 }), { 1, 2 }, 200)
			expect(state.sub).to.equal("clockout")
			expect(state.clockOutAt).to.equal(200 + LEAVE)
		end)

		it("keeps a running countdown's deadline as more punch", function()
			local counting = ShiftClockOutRules.settle(punched({ 1, 2 }), { 1, 2, 3, 4 }, 200)
			local more = ShiftClockOutRules.punch(counting, 3)
			local state = ShiftClockOutRules.settle(more, { 1, 2, 3, 4 }, 210)
			expect(state == nil or state.clockOutAt == 200 + LEAVE).to.equal(true)
		end)

		it("keeps counting down when the share drops below half (someone came back)", function()
			local counting = ShiftClockOutRules.settle(punched({ 1 }), { 1, 2 }, 200)
			local state = ShiftClockOutRules.settle(counting, { 1, 2, 3 }, 205)
			expect(state.crewIn).to.equal(3)
			expect(state.sub).to.equal("clockout")
			expect(state.clockOutAt).to.equal(200 + LEAVE)
		end)

		it("leaves at once when everyone still in has punched", function()
			local state = ShiftClockOutRules.settle(punched({ 1 }), { 1 }, 200)
			expect(state.sub).to.equal("clockout")
			expect(state.clockOutAt).to.equal(200)
		end)

		it("cuts the countdown short when the last one inside is caught or leaves", function()
			local counting = ShiftClockOutRules.settle(punched({ 1 }), { 1, 2 }, 200)
			local state = ShiftClockOutRules.settle(counting, { 1 }, 212)
			expect(state.clockOutAt).to.equal(212)
		end)

		it("never moves the deadline later", function()
			local leaving = ShiftClockOutRules.settle(punched({ 1 }), { 1 }, 200)
			expect(ShiftClockOutRules.settle(leaving, { 1 }, 203)).to.equal(nil)
		end)

		it("keeps the overtime stage through the countdown (assets x1.5 until the truck leaves)", function()
			local met = ShiftPhaseRules.markQuota(running(), 350, 150)
			local warned = ShiftPhaseRules.startOvertime(met, 160)
			local overtime = ShiftPhaseRules.advance(warned, 165 + ShiftConstants.WARNING_SECONDS)
			local state = ShiftClockOutRules.settle(ShiftClockOutRules.punch(overtime, 1), { 1, 2 }, 220)
			expect(state.sub).to.equal("clockout")
			expect(state.stage).to.equal("overtime")
			expect(ShiftPhaseRules.salvageMultiplier(state)).to.equal(ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER)
			expect(ShiftPhaseRules.canStartOvertime(state)).to.equal(false)
		end)

		it("clocks out when the punched member is the only one not knocked out", function()
			local stillIn = ShiftClockOutRules.stillIn({ 1, 2, 3 }, { 2, 3 })
			local state = ShiftClockOutRules.settle(punched({ 1 }), stillIn, 200)
			expect(state.sub).to.equal("clockout")
			expect(state.clockOutAt).to.equal(200)
		end)

		it("clocks out when everyone left in the shift has been knocked out after a punch", function()
			local stillIn = ShiftClockOutRules.stillIn({ 1, 2, 3 }, { 1, 2, 3 })
			expect(#stillIn).to.equal(0)
			local state = ShiftClockOutRules.settle(punched({ 1 }), stillIn, 200)
			expect(state.sub).to.equal("clockout")
			expect(state.clockOutAt).to.equal(200)
		end)

		it("keeps waiting while the only unpunched member is down but coming back", function()
			-- 2 is caught (dead, spectating) with lives left; 1 has punched.
			local stillIn = ShiftClockOutRules.stillIn({ 1, 2 }, { 2 })
			local state = ShiftClockOutRules.settle(punched({ 1 }), stillIn, 200, { 2 })
			expect(state.sub).to.equal("normal")
			expect(state.clockOutAt).to.equal(nil)
		end)

		it("leaves at once when the only unpunched member is knocked out, not merely down", function()
			local stillIn = ShiftClockOutRules.stillIn({ 1, 2 }, { 2 })
			local state = ShiftClockOutRules.settle(punched({ 1 }), stillIn, 200, {})
			expect(state.sub).to.equal("clockout")
			expect(state.clockOutAt).to.equal(200)
		end)

		it("leaves at once when the members who are down have punched", function()
			local stillIn = ShiftClockOutRules.stillIn({ 1, 2 }, {})
			local state = ShiftClockOutRules.settle(punched({ 1, 2 }), stillIn, 200, { 2 })
			expect(state.clockOutAt).to.equal(200)
		end)

		it("does not end a shift with a card punched while everyone else is down and coming back", function()
			local state = ShiftClockOutRules.settle(punched({ 1 }), {}, 200, { 2 })
			expect(state == nil or state.clockOutAt == nil).to.equal(true)
		end)

		it("waits with nobody still in and nobody punched", function()
			local state = ShiftClockOutRules.settle(running(), {}, 200)
			expect(state == nil or state.sub == "normal").to.equal(true)
		end)

		it("does nothing outside a running shift", function()
			expect(ShiftClockOutRules.settle(ShiftPhaseRules.initial(350, "B"), { 1 }, 0)).to.equal(nil)
		end)
	end)

	describe("countdownOver", function()
		it("is true once the truck's deadline is reached", function()
			local counting = ShiftClockOutRules.settle(punched({ 1 }), { 1, 2 }, 200)
			expect(ShiftClockOutRules.countdownOver(counting, 200 + LEAVE - 0.1)).to.equal(false)
			expect(ShiftClockOutRules.countdownOver(counting, 200 + LEAVE)).to.equal(true)
		end)

		it("is false without a countdown or outside a running shift", function()
			expect(ShiftClockOutRules.countdownOver(running(), 1000)).to.equal(false)
			expect(ShiftClockOutRules.countdownOver(ShiftPhaseRules.initial(350, "B"), 1000)).to.equal(false)
		end)
	end)

	describe("aboard", function()
		local low, high = Vector3.new(0, 0, 0), Vector3.new(10, 8, 20)

		it("is true inside the truck's box", function()
			expect(ShiftClockOutRules.aboard(Vector3.new(5, 3, 10), low, high)).to.equal(true)
		end)

		it("is false on the ramp or the bay floor", function()
			expect(ShiftClockOutRules.aboard(Vector3.new(5, 3, -2), low, high)).to.equal(false)
			expect(ShiftClockOutRules.aboard(Vector3.new(5, -1, 10), low, high)).to.equal(false)
			expect(ShiftClockOutRules.aboard(Vector3.new(12, 3, 10), low, high)).to.equal(false)
		end)
	end)
end
