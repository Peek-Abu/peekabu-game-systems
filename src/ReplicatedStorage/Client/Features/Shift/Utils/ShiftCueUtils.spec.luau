local ShiftCueUtils = require(script.Parent.ShiftCueUtils)

local function snapshot(overrides)
	local base = {
		phase = "running",
		sub = "normal",
		stage = "normal",
		tier = 0,
		shift = 1,
		endsAt = 520,
		quota = 350,
		cleared = 0,
		bonus = 0,
		quotaMet = false,
		variant = "B",
		votesAnother = 0,
		votesDepot = 0,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

return function()
	describe("cues", function()
		it("stays quiet on the first snapshot it sees", function()
			expect(#ShiftCueUtils.cues(nil, snapshot({ stage = "overtime", quotaMet = true, tier = 2 }))).to.equal(0)
			expect(#ShiftCueUtils.cues(snapshot(), nil)).to.equal(0)
		end)

		it("punches in when a run starts, and nothing else", function()
			local list = ShiftCueUtils.cues(snapshot({ phase = "starting" }), snapshot())
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("shiftStart")
		end)

		it("honks when the run ends", function()
			local list = ShiftCueUtils.cues(snapshot(), snapshot({ phase = "results" }))
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("shiftEnd")
		end)

		it("cues the quota once", function()
			local list = ShiftCueUtils.cues(snapshot(), snapshot({ quotaMet = true, stage = "break" }))
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("quotaMet")
			local met = snapshot({ quotaMet = true, stage = "break" })
			expect(#ShiftCueUtils.cues(met, met)).to.equal(0)
		end)

		it("cues a tier, the warning and overtime (overtime swallows its tier step)", function()
			expect(ShiftCueUtils.cues(snapshot(), snapshot({ tier = 1 }))[1]).to.equal("tierUp")
			local warning = ShiftCueUtils.cues(snapshot({ stage = "break" }), snapshot({ stage = "warning" }))
			expect(#warning).to.equal(1)
			expect(warning[1]).to.equal("warning")
			local overtime = ShiftCueUtils.cues(
				snapshot({ stage = "warning", tier = 1 }),
				snapshot({ stage = "overtime", tier = 2 })
			)
			expect(#overtime).to.equal(1)
			expect(overtime[1]).to.equal("overtime")
		end)

		it("honks the clock out", function()
			local list = ShiftCueUtils.cues(snapshot(), snapshot({ sub = "clockout", clockOutAt = 110 }))
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("clockOut")
		end)

		it("says nothing between two lobby snapshots", function()
			expect(#ShiftCueUtils.cues(snapshot({ phase = "lobby" }), snapshot({ phase = "lobby", shift = 2 }))).to.equal(
				0
			)
		end)
	end)

	describe("countdown", function()
		it("counts the clock out down in whole seconds, rounded up", function()
			local clocking = snapshot({ sub = "clockout", clockOutAt = 110 })
			expect(ShiftCueUtils.countdown(clocking, 100.2)).to.equal(10)
			expect(ShiftCueUtils.countdown(clocking, 109.5)).to.equal(1)
			expect(ShiftCueUtils.countdown(clocking, 111)).to.equal(0)
		end)

		it("is nil without a running clock out", function()
			expect(ShiftCueUtils.countdown(snapshot(), 100)).to.equal(nil)
			expect(ShiftCueUtils.countdown(snapshot({ phase = "results", sub = "clockout", clockOutAt = 110 }), 100)).to.equal(
				nil
			)
			expect(ShiftCueUtils.countdown(nil, 100)).to.equal(nil)
		end)
	end)

	describe("ticking", function()
		it("ticks in overtime only", function()
			expect(ShiftCueUtils.ticking(snapshot({ stage = "overtime" }))).to.equal(true)
			expect(ShiftCueUtils.ticking(snapshot({ stage = "warning" }))).to.equal(false)
			expect(ShiftCueUtils.ticking(nil)).to.equal(false)
		end)

		it("turns the ticking off when the run ends", function()
			expect(ShiftCueUtils.ticking(snapshot({ phase = "results", stage = "overtime" }))).to.equal(false)
		end)
	end)
end
