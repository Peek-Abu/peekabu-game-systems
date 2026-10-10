local ShiftHudViewModel = require(script.Parent.ShiftHudViewModel)

local function snapshot(extra)
	local value = {
		phase = "running",
		sub = "normal",
		shift = 1,
		endsAt = 1000,
		quota = 350,
		cleared = 120,
		bonus = 40,
		quotaMet = false,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local REVIEW = {
	outcome = "clockout",
	quota = 350,
	cleared = 380,
	bonus = 95,
	salvage = 3,
	piles = 12,
	quotaMet = true,
	crew = { { name = "Ava", banked = 200, piles = 6, salvage = 2 } },
	awards = { { title = "Top Hauler", name = "Ava" } },
}

return function()
	describe("clock", function()
		it("formats minutes and seconds, rounding up and never negative", function()
			expect(ShiftHudViewModel.clock(420)).to.equal("7:00")
			expect(ShiftHudViewModel.clock(61)).to.equal("1:01")
			expect(ShiftHudViewModel.clock(59.2)).to.equal("1:00")
			expect(ShiftHudViewModel.clock(0)).to.equal("0:00")
			expect(ShiftHudViewModel.clock(-5)).to.equal("0:00")
		end)
	end)

	describe("hud", function()
		it("shows nothing outside a running shift", function()
			expect(ShiftHudViewModel.hud(nil, nil, 0)).to.equal(nil)
			expect(ShiftHudViewModel.hud(snapshot({ phase = "results" }), nil, 0)).to.equal(nil)
		end)

		it("shows the timer, clearance, bonus and canister", function()
			local view = ShiftHudViewModel.hud(snapshot(), { canister = 2 }, 580)
			expect(view.timer).to.equal("Shift 1 | 7:00")
			expect(view.clearance).to.equal("Clearance 120 / 350")
			expect(view.bonus).to.equal("Bonus 40")
			expect(view.canister).to.equal("Canister 2 / 3")
			expect(view.quotaMet).to.equal(false)
			expect(view.clockOut).to.equal(nil)
		end)

		it("names the hands item and the pockets, an empty one as a dash", function()
			local view = ShiftHudViewModel.hud(snapshot(), { carrying = "monitor", pocket1 = "plaque" }, 0)
			expect(view.hands).to.equal("Hands: Monitor")
			expect(view.pockets).to.equal("Pockets: Employee of the Month plaque | -")
		end)

		it("reads an absent canister and empty hands", function()
			local view = ShiftHudViewModel.hud(snapshot(), nil, 0)
			expect(view.canister).to.equal("Canister 0 / 3")
			expect(view.hands).to.equal("Hands: -")
			expect(view.pockets).to.equal("Pockets: - | -")
		end)

		it("shows the clock-out countdown and the quota flag", function()
			local view =
				ShiftHudViewModel.hud(snapshot({ sub = "clockout", clockOutAt = 107, quotaMet = true }), nil, 100)
			expect(view.clockOut).to.equal("CLOCKING OUT 0:07")
			expect(view.quotaMet).to.equal(true)
		end)
	end)

	describe("results", function()
		it("shows nothing outside results", function()
			expect(ShiftHudViewModel.results(snapshot(), 0)).to.equal(nil)
			expect(ShiftHudViewModel.results(nil, 0)).to.equal(nil)
		end)

		it("lists the review and the vote", function()
			local view = ShiftHudViewModel.results(
				snapshot({ phase = "results", voteEndsAt = 130, votesAnother = 2, votesDepot = 1, results = REVIEW }),
				100
			)
			expect(view.title).to.equal("Shift 1 performance review")
			expect(view.lines[1]).to.equal("Clocked out")
			expect(view.lines[2]).to.equal("Cleared 380 / 350 - QUOTA MET")
			expect(view.lines[3]).to.equal("Bonus 95")
			expect(view.lines[4]).to.equal("Salvage found 3 | Piles vacuumed 12")
			expect(view.lines[5]).to.equal("Ava: banked 200, piles 6")
			expect(view.lines[6]).to.equal("Top Hauler: Ava")
			expect(view.another).to.equal("Another shift (2)")
			expect(view.depot).to.equal("Back to depot (1)")
			expect(view.countdown).to.equal("Deciding in 0:30")
		end)

		it("says when the quota was missed and the time ran out", function()
			local review = table.clone(REVIEW)
			review.outcome = "timeout"
			review.cleared = 200
			review.quotaMet = false
			local view =
				ShiftHudViewModel.results(snapshot({ phase = "results", voteEndsAt = 100, results = review }), 100)
			expect(view.lines[1]).to.equal("Time's up")
			expect(view.lines[2]).to.equal("Cleared 200 / 350 - quota missed")
		end)

		it("handles an empty crew", function()
			local review = table.clone(REVIEW)
			review.crew = {}
			local view =
				ShiftHudViewModel.results(snapshot({ phase = "results", voteEndsAt = 100, results = review }), 100)
			expect(view.lines[5]).to.equal("Top Hauler: Ava")
			expect(#view.lines).to.equal(5)
		end)

		it("still offers the vote when the review has not arrived", function()
			local view = ShiftHudViewModel.results(snapshot({ phase = "results", voteEndsAt = 130 }), 100)
			expect(#view.lines).to.equal(0)
			expect(view.title).to.equal("Shift 1 performance review")
			expect(view.another).to.equal("Another shift (0)")
			expect(view.depot).to.equal("Back to depot (0)")
			expect(view.countdown).to.equal("Deciding in 0:30")
		end)
	end)
end
