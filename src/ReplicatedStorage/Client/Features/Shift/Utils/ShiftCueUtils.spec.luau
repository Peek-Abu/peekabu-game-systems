local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftCueUtils = require(script.Parent.ShiftCueUtils)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftAssets = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftAssets)

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
		punched = {},
		crewIn = 0,
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

		it("punches a card when a crew member clocks out, once per punch", function()
			local list = ShiftCueUtils.cues(snapshot({ crewIn = 3 }), snapshot({ punched = { 4 }, crewIn = 3 }))
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("punch")
			local one = snapshot({ punched = { 4 }, crewIn = 3 })
			expect(#ShiftCueUtils.cues(one, one)).to.equal(0)
		end)

		it("punches, then honks, when a punch starts the truck's countdown", function()
			local list = ShiftCueUtils.cues(
				snapshot({ crewIn = 2 }),
				snapshot({ punched = { 4 }, crewIn = 2, sub = "clockout", clockOutAt = 130 })
			)
			expect(#list).to.equal(2)
			expect(list[1]).to.equal("punch")
			expect(list[2]).to.equal("clockOut")
		end)

		-- Owner Night Shift pick 2026-11-18 (vote B): a small stamp each time someone in the crew votes.
		it("stamps each new vote on the review, once per vote", function()
			local before = snapshot({ phase = "results" })
			local list = ShiftCueUtils.cues(before, snapshot({ phase = "results", votesAnother = 1 }))
			expect(#list).to.equal(1)
			expect(list[1]).to.equal("vote")
			local one = snapshot({ phase = "results", votesAnother = 1 })
			expect(#ShiftCueUtils.cues(one, one)).to.equal(0)
			expect(ShiftCueUtils.cues(one, snapshot({ phase = "results", votesAnother = 1, votesDepot = 1 }))[1]).to.equal(
				"vote"
			)
		end)

		it("stays quiet when the votes clear or outside the review", function()
			local voted = snapshot({ phase = "results", votesAnother = 2 })
			expect(#ShiftCueUtils.cues(voted, snapshot({ phase = "results" }))).to.equal(0)
			expect(#ShiftCueUtils.cues(snapshot({ phase = "lobby" }), snapshot({ phase = "lobby", votesDepot = 1 }))).to.equal(
				0
			)
		end)

		it("maps the vote to the picked stamp", function()
			expect(ShiftAssets.CUE_SOUNDS.vote).to.equal("shiftVoteCast")
			expect(ShiftAssets.SOUNDS.shiftVoteCast.assetId).to.equal("rbxassetid://109681425017833")
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

	describe("tickScale", function()
		it("ticks only the countdown's last seconds, louder at the very end", function()
			expect(ShiftCueUtils.tickScale(ShiftConstants.COUNTDOWN_TICKS + 1)).to.equal(nil)
			expect(ShiftCueUtils.tickScale(ShiftConstants.COUNTDOWN_TICKS)).to.equal(1)
			expect(ShiftCueUtils.tickScale(ShiftConstants.COUNTDOWN_LOUD)).to.equal(ShiftConstants.COUNTDOWN_LOUD_SCALE)
			expect(ShiftCueUtils.tickScale(1)).to.equal(ShiftConstants.COUNTDOWN_LOUD_SCALE)
		end)

		it("is silent at zero and without a countdown", function()
			expect(ShiftCueUtils.tickScale(0)).to.equal(nil)
			expect(ShiftCueUtils.tickScale(nil)).to.equal(nil)
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

	describe("jingle", function()
		local function review(met, overtimeSalvage)
			return {
				outcome = "clockout",
				quota = 350,
				cleared = if met then 360 else 200,
				bonus = 0,
				salvage = 3,
				piles = 10,
				catches = 0,
				offered = 6,
				rating = "satisfactory",
				quotaMet = met,
				crew = {
					{ userId = 1, name = "A", banked = 0, piles = 0, salvage = 0, caught = 0, overtimeSalvage = 0 },
					{
						userId = 2,
						name = "B",
						banked = 0,
						piles = 0,
						salvage = 0,
						caught = 0,
						overtimeSalvage = overtimeSalvage,
					},
				},
				awards = {},
			}
		end

		it("plays when the review arrives: met, met with overtime salvage, or missed", function()
			local running = snapshot()
			expect(ShiftCueUtils.jingle(running, snapshot({ phase = "results", results = review(true, 0) }))).to.equal(
				"met"
			)
			expect(ShiftCueUtils.jingle(running, snapshot({ phase = "results", results = review(true, 2) }))).to.equal(
				"overtime"
			)
			expect(ShiftCueUtils.jingle(running, snapshot({ phase = "results", results = review(false, 2) }))).to.equal(
				"missed"
			)
		end)

		it("plays when the review lands after the results phase began", function()
			local waiting = snapshot({ phase = "results" })
			expect(ShiftCueUtils.jingle(waiting, snapshot({ phase = "results", results = review(true, nil) }))).to.equal(
				"met"
			)
		end)

		it("plays once: not again while the review stays, not on the first snapshot, not without a review", function()
			local shown = snapshot({ phase = "results", results = review(true, 0) })
			expect(ShiftCueUtils.jingle(shown, snapshot({ phase = "results", results = review(true, 0) }))).to.equal(
				nil
			)
			expect(ShiftCueUtils.jingle(nil, shown)).to.equal(nil)
			expect(ShiftCueUtils.jingle(snapshot(), snapshot({ phase = "results" }))).to.equal(nil)
			expect(ShiftCueUtils.jingle(snapshot(), snapshot())).to.equal(nil)
		end)

		-- Owner Night Shift pick 2026-11-18 (week report B): a survived week's last night plays the week stinger in
		-- place of the met jingle (the review shows WEEK N DONE!).
		it("plays the week stinger on a survived week's report", function()
			local running = snapshot({ runMode = "night", night = 5, week = 1 })
			local report = snapshot({
				phase = "results",
				results = review(true, 0),
				runMode = "night",
				night = 5,
				week = 1,
				weekBonus = 100,
			})
			expect(ShiftCueUtils.jingle(running, report)).to.equal("week")
			expect(ShiftAssets.JINGLE_SOUNDS.week).to.equal("shiftWeekDone")
			expect(ShiftAssets.SOUNDS.shiftWeekDone.assetId).to.equal("rbxassetid://107812332958746")
		end)

		it("keeps the usual jingle on other nights and once the run is over", function()
			local running = snapshot({ runMode = "night", night = 3 })
			expect(
				ShiftCueUtils.jingle(
					running,
					snapshot({ phase = "results", results = review(true, 0), runMode = "night", night = 3 })
				)
			).to.equal("met")
			local over = snapshot({
				phase = "results",
				results = review(false, 0),
				runMode = "night",
				night = 5,
				weekBonus = 100,
				runOver = "fired",
			})
			expect(ShiftCueUtils.jingle(running, over)).to.equal("missed")
		end)
	end)
end
