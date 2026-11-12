local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingStepRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingStepRules)

local RUN = TrainingConstants.RUN_SECONDS

-- A tick's facts with nothing happening, at server time `now`.
local function quiet(now)
	return { dt = 0.1, sprinting = false, readyAt = 0, pressed = false, now = now }
end

return function()
	describe("order", function()
		it("goes gloom, then run, then power", function()
			local state = TrainingStepRules.new(true)
			expect(TrainingStepRules.current(state)).to.equal("gloom")
			expect(TrainingStepRules.cleared(state)).to.equal(true)
			expect(TrainingStepRules.current(state)).to.equal("run")
			TrainingStepRules.tick(state, { dt = RUN + 0.1, sprinting = true, readyAt = 0, pressed = false, now = 10 })
			expect(TrainingStepRules.current(state)).to.equal("power")
			TrainingStepRules.tick(state, { dt = 0.1, sprinting = false, readyAt = 0, pressed = true, now = 11 })
			expect(TrainingStepRules.current(state)).to.equal(nil)
			expect(TrainingStepRules.done(state)).to.equal(true)
		end)

		it("skips the power step for an employee without a power", function()
			local state = TrainingStepRules.new(false)
			TrainingStepRules.cleared(state)
			TrainingStepRules.tick(state, { dt = RUN + 0.1, sprinting = true, readyAt = 0, pressed = false, now = 10 })
			expect(TrainingStepRules.done(state)).to.equal(true)
		end)
	end)

	describe("nothing counts before its step", function()
		it("ignores running and the power while the gloom step is on", function()
			local state = TrainingStepRules.new(true)
			expect(TrainingStepRules.tick(state, { dt = 5, sprinting = true, readyAt = 50, pressed = true, now = 10 })).to.equal(
				false
			)
			expect(TrainingStepRules.current(state)).to.equal("gloom")
			TrainingStepRules.cleared(state)
			-- The earlier sprint did not carry over into the run step.
			TrainingStepRules.tick(state, { dt = RUN / 2, sprinting = true, readyAt = 50, pressed = false, now = 11 })
			expect(TrainingStepRules.current(state)).to.equal("run")
		end)

		it("ignores the power while the run step is on", function()
			local state = TrainingStepRules.new(true)
			TrainingStepRules.cleared(state)
			TrainingStepRules.tick(state, { dt = 0.1, sprinting = false, readyAt = 0, pressed = true, now = 10 })
			expect(TrainingStepRules.current(state)).to.equal("run")
		end)

		it("does not take the gloom again once past it", function()
			local state = TrainingStepRules.new(true)
			TrainingStepRules.cleared(state)
			expect(TrainingStepRules.cleared(state)).to.equal(false)
			expect(TrainingStepRules.current(state)).to.equal("run")
		end)
	end)

	describe("run", function()
		it("adds up only the time spent sprinting", function()
			local state = TrainingStepRules.new(true)
			TrainingStepRules.cleared(state)
			TrainingStepRules.tick(state, { dt = RUN * 0.6, sprinting = true, readyAt = 0, pressed = false, now = 10 })
			TrainingStepRules.tick(state, { dt = 5, sprinting = false, readyAt = 0, pressed = false, now = 11 })
			expect(TrainingStepRules.current(state)).to.equal("run")
			TrainingStepRules.tick(state, { dt = RUN * 0.6, sprinting = true, readyAt = 0, pressed = false, now = 12 })
			expect(TrainingStepRules.current(state)).to.equal("power")
		end)
	end)

	describe("power", function()
		local function atPower(readyAt, now)
			local state = TrainingStepRules.new(true)
			TrainingStepRules.cleared(state)
			TrainingStepRules.tick(
				state,
				{ dt = RUN + 0.1, sprinting = true, readyAt = readyAt, pressed = false, now = now }
			)
			return state
		end

		it("passes on a real use: the ready time moves into the future", function()
			local state = atPower(0, 10)
			expect(TrainingStepRules.tick(state, quiet(11))).to.equal(false)
			expect(
				TrainingStepRules.tick(state, { dt = 0.1, sprinting = false, readyAt = 30, pressed = false, now = 12 })
			).to.equal(true)
			expect(TrainingStepRules.done(state)).to.equal(true)
		end)

		it("does not pass on a cooldown that was already running when the step began", function()
			local state = atPower(25, 10)
			expect(
				TrainingStepRules.tick(state, { dt = 0.1, sprinting = false, readyAt = 25, pressed = false, now = 11 })
			).to.equal(false)
			expect(TrainingStepRules.current(state)).to.equal("power")
		end)

		it("passes on a press of the power button even when the power could not fire here", function()
			local state = atPower(0, 10)
			TrainingStepRules.tick(state, { dt = 0.1, sprinting = false, readyAt = 0, pressed = true, now = 11 })
			expect(TrainingStepRules.done(state)).to.equal(true)
		end)
	end)
end
