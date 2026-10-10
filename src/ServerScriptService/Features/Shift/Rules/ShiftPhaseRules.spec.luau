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

local function running()
	return ShiftPhaseRules.follow(ShiftPhaseRules.initial(350, "B"), round("running", { endsAt = 520 }), 100)
end

local function results()
	return ShiftPhaseRules.follow(running(), round("results", { outcome = "timeout" }), 600)
end

return function()
	it("starts in the lobby with the quota and variant", function()
		local state = ShiftPhaseRules.initial(350, "A")
		expect(state.phase).to.equal("lobby")
		expect(state.sub).to.equal("normal")
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

		it("enters running with the shift number and end time, quota unmet", function()
			local state = running()
			expect(state.phase).to.equal("running")
			expect(state.sub).to.equal("normal")
			expect(state.shift).to.equal(1)
			expect(state.endsAt).to.equal(520)
			expect(state.quotaMet).to.equal(false)
		end)

		it("holds results with a vote deadline when Round shows results", function()
			local state = results()
			expect(state.phase).to.equal("results")
			expect(state.voteEndsAt).to.equal(600 + ShiftConstants.VOTE_SECONDS)
			expect(state.endsAt).to.equal(nil)
			expect(state.clockOutAt).to.equal(nil)
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
	end)

	describe("markQuota", function()
		it("marks the quota met once it is reached", function()
			expect(ShiftPhaseRules.markQuota(running(), 349)).to.equal(nil)
			local state = ShiftPhaseRules.markQuota(running(), 350)
			expect(state.quotaMet).to.equal(true)
			expect(ShiftPhaseRules.markQuota(state, 400)).to.equal(nil)
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
		local state = ShiftPhaseRules.toLobby(ShiftPhaseRules.markQuota(ShiftPhaseRules.clockOut(running(), 200), 400))
		expect(state.phase).to.equal("lobby")
		expect(state.sub).to.equal("normal")
		expect(state.shift).to.equal(1)
		expect(state.quotaMet).to.equal(false)
		expect(state.clockOutAt).to.equal(nil)
		expect(state.endsAt).to.equal(nil)
		expect(state.quota).to.equal(350)
	end)
end
