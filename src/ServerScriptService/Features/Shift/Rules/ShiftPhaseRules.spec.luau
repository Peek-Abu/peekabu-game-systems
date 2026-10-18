local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftPhaseRules = require(script.Parent.ShiftPhaseRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local function round(phase, extra)
	local state = { phase = phase, round = 1 }
	for key, value in extra or {} do
		state[key] = value
	end
	return state
end

-- A shift that started running at 100 and ends at 520.
local function running()
	return ShiftPhaseRules.follow(ShiftPhaseRules.initial(350, "B"), round("running", { endsAt = 520 }), 100)
end

local function results()
	return ShiftPhaseRules.follow(running(), round("results", { outcome = "timeout" }), 600)
end

-- Quota met at 150: the Manager's break until 180. Overtime starts only when the crew asks for it.
local function onBreak()
	return ShiftPhaseRules.markQuota(running(), 350, 150)
end

-- The crew starts overtime at 160 (during the break): the warning runs until 160 + WARNING_SECONDS.
local function warned()
	return ShiftPhaseRules.startOvertime(onBreak(), 160)
end

-- Overtime proper, five seconds after the warning ran out.
local function overtime()
	return ShiftPhaseRules.advance(warned(), 165 + ShiftConstants.WARNING_SECONDS)
end

-- `state` with the truck's countdown running (ShiftClockOutRules), the truck leaving at `at`.
local function clockingOut(state, at)
	local nextState = table.clone(state)
	nextState.sub = "clockout"
	nextState.clockOutAt = at
	return nextState
end

return function()
	it("starts in the lobby with the quota and variant", function()
		local state = ShiftPhaseRules.initial(350, "A")
		expect(state.phase).to.equal("lobby")
		expect(state.sub).to.equal("normal")
		expect(state.stage).to.equal("normal")
		expect(state.tier).to.equal(0)
		expect(state.shift).to.equal(0)
		expect(state.quota).to.equal(350)
		expect(state.variant).to.equal("A")
		expect(state.quotaMet).to.equal(false)
	end)

	describe("transit", function()
		it("enters starting from the lobby, ending at the transit's deadline, keeping the shift count", function()
			local state = ShiftPhaseRules.transit(ShiftPhaseRules.initial(350, "B"), 120)
			expect(state.phase).to.equal("starting")
			expect(state.endsAt).to.equal(120)
			expect(state.shift).to.equal(0)
			expect(state.quota).to.equal(350)
		end)

		it("enters starting from results (Another shift), clearing the review's pacing and vote", function()
			local state = ShiftPhaseRules.transit(results(), 700)
			expect(state.phase).to.equal("starting")
			expect(state.endsAt).to.equal(700)
			expect(state.voteEndsAt).to.equal(nil)
			expect(state.quotaMet).to.equal(false)
			expect(state.shift).to.equal(1)
		end)

		it("is refused while starting or running", function()
			local starting = ShiftPhaseRules.transit(ShiftPhaseRules.initial(350, "B"), 120)
			expect(ShiftPhaseRules.transit(starting, 130)).to.equal(nil)
			expect(ShiftPhaseRules.transit(running(), 130)).to.equal(nil)
		end)

		it("leaves the transit for running when Round starts the run", function()
			local starting = ShiftPhaseRules.transit(ShiftPhaseRules.initial(350, "B"), 120)
			local state = ShiftPhaseRules.follow(starting, round("running", { endsAt = 540 }), 110)
			expect(state.phase).to.equal("running")
			expect(state.startedAt).to.equal(110)
		end)

		it("ticks nothing during the transit", function()
			local starting = ShiftPhaseRules.transit(ShiftPhaseRules.initial(350, "B"), 120)
			expect(ShiftPhaseRules.tick(starting, 200, 2)).to.equal("none")
		end)
	end)

	describe("follow", function()
		it("enters starting with Round's countdown", function()
			local state =
				ShiftPhaseRules.follow(ShiftPhaseRules.initial(350, "B"), round("starting", { endsAt = 105 }), 100)
			expect(state.phase).to.equal("starting")
			expect(state.endsAt).to.equal(105)
		end)

		it("enters running with the shift number, start and end time, quota unmet, normal stage", function()
			local state = running()
			expect(state.phase).to.equal("running")
			expect(state.sub).to.equal("normal")
			expect(state.stage).to.equal("normal")
			expect(state.tier).to.equal(0)
			expect(state.shift).to.equal(1)
			expect(state.startedAt).to.equal(100)
			expect(state.endsAt).to.equal(520)
			expect(state.quotaMet).to.equal(false)
		end)

		it("holds results with a vote deadline when Round shows results, pacing cleared", function()
			local state = ShiftPhaseRules.follow(overtime(), round("results"), 600)
			expect(state.phase).to.equal("results")
			expect(state.voteEndsAt).to.equal(600 + ShiftConstants.VOTE_SECONDS)
			expect(state.endsAt).to.equal(nil)
			expect(state.clockOutAt).to.equal(nil)
			expect(state.stage).to.equal("normal")
			expect(state.stageEndsAt).to.equal(nil)
			expect(state.tier).to.equal(0)
			expect(state.quotaMet).to.equal(true)
		end)

		it("stays in results when Round goes back to its lobby", function()
			expect(ShiftPhaseRules.follow(results(), round("lobby"), 601)).to.equal(nil)
		end)

		it("goes back to the lobby when a countdown is cancelled", function()
			local starting =
				ShiftPhaseRules.follow(ShiftPhaseRules.initial(350, "B"), round("starting", { endsAt = 5 }), 0)
			expect(ShiftPhaseRules.follow(starting, round("lobby"), 1).phase).to.equal("lobby")
		end)

		it("ignores a phase it already follows", function()
			expect(ShiftPhaseRules.follow(running(), round("running", { endsAt = 520 }), 101)).to.equal(nil)
		end)
	end)

	describe("markQuota", function()
		it("marks the quota met once it is reached and starts the break", function()
			expect(ShiftPhaseRules.markQuota(running(), 349, 150)).to.equal(nil)
			local state = ShiftPhaseRules.markQuota(running(), 350, 150)
			expect(state.quotaMet).to.equal(true)
			expect(state.stage).to.equal("break")
			expect(state.stageEndsAt).to.equal(150 + ShiftConstants.BREAK_SECONDS)
			expect(ShiftPhaseRules.markQuota(state, 400, 160)).to.equal(nil)
		end)

		it("ignores clearance outside a running shift", function()
			expect(ShiftPhaseRules.markQuota(ShiftPhaseRules.initial(350, "B"), 500, 0)).to.equal(nil)
		end)
	end)

	describe("startOvertime", function()
		it("is refused until the quota is met", function()
			expect(ShiftPhaseRules.canStartOvertime(running())).to.equal(false)
			expect(ShiftPhaseRules.startOvertime(running(), 120)).to.equal(nil)
		end)

		it("starts the overtime warning during the break", function()
			expect(ShiftPhaseRules.canStartOvertime(onBreak())).to.equal(true)
			local state = warned()
			expect(state.stage).to.equal("warning")
			expect(state.stageEndsAt).to.equal(160 + ShiftConstants.WARNING_SECONDS)
			expect(state.quotaMet).to.equal(true)
		end)

		it("can still be started after the break is over", function()
			local back = ShiftPhaseRules.advance(onBreak(), 200)
			expect(ShiftPhaseRules.canStartOvertime(back)).to.equal(true)
			local state = ShiftPhaseRules.startOvertime(back, 300)
			expect(state.stage).to.equal("warning")
			expect(state.stageEndsAt).to.equal(300 + ShiftConstants.WARNING_SECONDS)
		end)

		it("is started once: refused during the warning and in overtime", function()
			expect(ShiftPhaseRules.canStartOvertime(warned())).to.equal(false)
			expect(ShiftPhaseRules.startOvertime(warned(), 170)).to.equal(nil)
			expect(ShiftPhaseRules.canStartOvertime(overtime())).to.equal(false)
			expect(ShiftPhaseRules.startOvertime(overtime(), 220)).to.equal(nil)
		end)

		it("is refused once the crew is clocking out, and outside a running shift", function()
			local leaving = clockingOut(onBreak(), 185)
			expect(ShiftPhaseRules.canStartOvertime(leaving)).to.equal(false)
			expect(ShiftPhaseRules.startOvertime(leaving, 156)).to.equal(nil)
			expect(ShiftPhaseRules.startOvertime(ShiftPhaseRules.initial(350, "B"), 0)).to.equal(nil)
			expect(ShiftPhaseRules.startOvertime(results(), 610)).to.equal(nil)
		end)
	end)

	describe("advance", function()
		it("ends the break at its deadline without starting overtime", function()
			expect(ShiftPhaseRules.advance(onBreak(), 179)).to.equal(nil)
			local back = ShiftPhaseRules.advance(onBreak(), 180)
			expect(back.stage).to.equal("normal")
			expect(back.stageEndsAt).to.equal(nil)
			expect(back.quotaMet).to.equal(true)
			-- However long the crew stays, the clock alone never starts overtime.
			expect(ShiftPhaseRules.advance(back, 519).stage).to.equal("normal")
		end)

		it("steps the warning into overtime at its deadline", function()
			local deadline = 160 + ShiftConstants.WARNING_SECONDS
			expect(ShiftPhaseRules.advance(warned(), deadline - 1)).to.equal(nil)
			local state = ShiftPhaseRules.advance(warned(), deadline)
			expect(state.stage).to.equal("overtime")
			expect(state.stageEndsAt).to.equal(nil)
		end)

		it("puts overtime at the top tier", function()
			local state = overtime()
			expect(state.stage).to.equal("overtime")
			expect(state.tier).to.equal(ShiftConstants.TOP_TIER)
			expect(ShiftPhaseRules.advance(state, 216)).to.equal(nil)
		end)

		it("raises the tier at 2:00 and 4:00 into the shift, and never past the top", function()
			local state = running()
			expect(ShiftPhaseRules.advance(state, 100 + 119)).to.equal(nil)
			local tier1 = ShiftPhaseRules.advance(state, 100 + 120)
			expect(tier1.tier).to.equal(1)
			expect(ShiftPhaseRules.advance(tier1, 100 + 200)).to.equal(nil)
			local tier2 = ShiftPhaseRules.advance(tier1, 100 + 240)
			expect(tier2.tier).to.equal(2)
			expect(ShiftPhaseRules.advance(tier2, 100 + 400)).to.equal(nil)
		end)

		it("ignores a shift that is not running", function()
			expect(ShiftPhaseRules.advance(ShiftPhaseRules.initial(350, "B"), 1000)).to.equal(nil)
			expect(ShiftPhaseRules.advance(results(), 1000)).to.equal(nil)
		end)
	end)

	describe("tierAt and salvageMultiplier", function()
		it("reads the tier from the shift's start", function()
			expect(ShiftPhaseRules.tierAt(running(), 150)).to.equal(0)
			expect(ShiftPhaseRules.tierAt(running(), 230)).to.equal(1)
			expect(ShiftPhaseRules.tierAt(running(), 350)).to.equal(2)
			expect(ShiftPhaseRules.tierAt(ShiftPhaseRules.initial(350, "B"), 9999)).to.equal(0)
		end)

		it("multiplies salvage only in overtime", function()
			expect(ShiftPhaseRules.salvageMultiplier(running())).to.equal(ShiftConstants.SALVAGE_MULTIPLIER)
			expect(ShiftPhaseRules.salvageMultiplier(onBreak())).to.equal(ShiftConstants.SALVAGE_MULTIPLIER)
			expect(ShiftPhaseRules.salvageMultiplier(ShiftPhaseRules.advance(onBreak(), 180))).to.equal(
				ShiftConstants.SALVAGE_MULTIPLIER
			)
			expect(ShiftPhaseRules.salvageMultiplier(warned())).to.equal(ShiftConstants.SALVAGE_MULTIPLIER)
			expect(ShiftPhaseRules.salvageMultiplier(overtime())).to.equal(1.5)
		end)
	end)

	describe("tick", function()
		it("asks to start when someone waits in the lobby", function()
			expect(ShiftPhaseRules.tick(ShiftPhaseRules.initial(350, "B"), 0, 1)).to.equal("start")
		end)

		it("never starts an empty server", function()
			expect(ShiftPhaseRules.tick(ShiftPhaseRules.initial(350, "B"), 0, 0)).to.equal("none")
		end)

		it("ends the shift when the clock-out countdown runs out", function()
			local state = clockingOut(running(), 210)
			expect(ShiftPhaseRules.tick(state, 209.9, 1)).to.equal("none")
			expect(ShiftPhaseRules.tick(state, 210, 1)).to.equal("endShift")
		end)

		it("resolves the vote when its time is up", function()
			local deadline = 600 + ShiftConstants.VOTE_SECONDS
			expect(ShiftPhaseRules.tick(results(), deadline - 1, 1)).to.equal("none")
			expect(ShiftPhaseRules.tick(results(), deadline, 1)).to.equal("resolveVote")
		end)

		it("does nothing mid-shift", function()
			expect(ShiftPhaseRules.tick(running(), 300, 3)).to.equal("none")
		end)
	end)

	it("returns to the lobby keeping the shift count and clearing the run", function()
		local met = ShiftPhaseRules.markQuota(clockingOut(running(), 230), 400, 200)
		local state = ShiftPhaseRules.toLobby(met)
		expect(state.phase).to.equal("lobby")
		expect(state.sub).to.equal("normal")
		expect(state.stage).to.equal("normal")
		expect(state.stageEndsAt).to.equal(nil)
		expect(state.tier).to.equal(0)
		expect(state.shift).to.equal(1)
		expect(state.quotaMet).to.equal(false)
		expect(state.clockOutAt).to.equal(nil)
		expect(state.endsAt).to.equal(nil)
		expect(state.startedAt).to.equal(nil)
		expect(state.quota).to.equal(350)
	end)
end
