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

-- Quota met at 150: break until 180, warning until 210, then overtime.
local function onBreak()
	return ShiftPhaseRules.markQuota(running(), 350, 150)
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
			local state = ShiftPhaseRules.follow(ShiftPhaseRules.advance(onBreak(), 215), round("results"), 600)
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

	describe("clockOut", function()
		it("starts one countdown while running", function()
			local state = ShiftPhaseRules.clockOut(running(), 200)
			expect(state.sub).to.equal("clockout")
			expect(state.clockOutAt).to.equal(200 + ShiftConstants.CLOCK_OUT_SECONDS)
		end)

		it("ignores a second press during the countdown", function()
			local state = ShiftPhaseRules.clockOut(running(), 200)
			expect(ShiftPhaseRules.clockOut(state, 205)).to.equal(nil)
		end)

		it("ignores a press outside a running shift", function()
			expect(ShiftPhaseRules.clockOut(ShiftPhaseRules.initial(350, "B"), 0)).to.equal(nil)
			expect(ShiftPhaseRules.clockOut(results(), 610)).to.equal(nil)
		end)

		it("keeps the overtime stage through a clock out", function()
			local overtime = ShiftPhaseRules.advance(onBreak(), 215)
			local state = ShiftPhaseRules.clockOut(overtime, 220)
			expect(state.sub).to.equal("clockout")
			expect(state.stage).to.equal("overtime")
			expect(ShiftPhaseRules.salvageMultiplier(state)).to.equal(ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER)
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

	describe("advance", function()
		it("steps the break into the warning, then overtime", function()
			expect(ShiftPhaseRules.advance(onBreak(), 179)).to.equal(nil)
			local warning = ShiftPhaseRules.advance(onBreak(), 180)
			expect(warning.stage).to.equal("warning")
			expect(warning.stageEndsAt).to.equal(180 + ShiftConstants.WARNING_SECONDS)
			expect(ShiftPhaseRules.advance(warning, 209)).to.equal(nil)
			local overtime = ShiftPhaseRules.advance(warning, 210)
			expect(overtime.stage).to.equal("overtime")
			expect(overtime.stageEndsAt).to.equal(nil)
		end)

		it("puts overtime at the top tier", function()
			local overtime = ShiftPhaseRules.advance(onBreak(), 215)
			expect(overtime.stage).to.equal("overtime")
			expect(overtime.tier).to.equal(ShiftConstants.TOP_TIER)
			expect(ShiftPhaseRules.advance(overtime, 216)).to.equal(nil)
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
			expect(ShiftPhaseRules.salvageMultiplier(ShiftPhaseRules.advance(onBreak(), 215))).to.equal(1.5)
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
			local state = ShiftPhaseRules.clockOut(running(), 200)
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
		local met = ShiftPhaseRules.markQuota(ShiftPhaseRules.clockOut(running(), 200), 400, 200)
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
