local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingStopRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingStopRules)

return function()
	describe("new", function()
		it("starts on stop 1 with nothing done", function()
			local state = TrainingStopRules.new()
			expect(state.stop).to.equal(1)
			expect(TrainingStopRules.isDone(state, 1)).to.equal(false)
			expect(state.finished).to.equal(false)
		end)
	end)

	describe("complete", function()
		it("finishes the current stop's own goal once", function()
			local state = TrainingStopRules.new()
			expect(TrainingStopRules.complete(state, 1, "piles")).to.equal(true)
			expect(TrainingStopRules.isDone(state, 1)).to.equal(true)
			expect(TrainingStopRules.complete(state, 1, "piles")).to.equal(false)
		end)

		it("ignores the wrong goal for a stop", function()
			local state = TrainingStopRules.new()
			expect(TrainingStopRules.complete(state, 1, "banked")).to.equal(false)
		end)

		it("can finish a stop's goal before the player walks in (a pile vacuumed from the doorway)", function()
			local state = TrainingStopRules.new()
			TrainingStopRules.complete(state, 1, "piles")
			expect(TrainingStopRules.complete(state, 2, "banked")).to.equal(true)
			TrainingStopRules.enter(state, 2)
			expect(TrainingStopRules.enter(state, 3)).to.equal(true)
		end)

		it("ignores a goal two stops ahead", function()
			local state = TrainingStopRules.new()
			expect(TrainingStopRules.complete(state, 2, "banked")).to.equal(false)
		end)
	end)

	describe("enter", function()
		it("needs the stop before to be done when it has its own goal", function()
			local state = TrainingStopRules.new()
			expect(TrainingStopRules.enter(state, 2)).to.equal(false)
			TrainingStopRules.complete(state, 1, "piles")
			expect(TrainingStopRules.enter(state, 2)).to.equal(true)
			expect(state.stop).to.equal(2)
		end)

		it("never skips a stop and never goes back", function()
			local state = TrainingStopRules.new()
			TrainingStopRules.complete(state, 1, "piles")
			expect(TrainingStopRules.enter(state, 3)).to.equal(false)
			TrainingStopRules.enter(state, 2)
			expect(TrainingStopRules.enter(state, 1)).to.equal(false)
			expect(TrainingStopRules.enter(state, 2)).to.equal(false)
		end)

		it("marks a walk stop done by walking into the next one, and finishes at the last", function()
			local state = TrainingStopRules.new()
			TrainingStopRules.complete(state, 1, "piles")
			TrainingStopRules.enter(state, 2)
			TrainingStopRules.complete(state, 2, "banked")
			expect(TrainingStopRules.enter(state, 3)).to.equal(true)
			expect(TrainingStopRules.enter(state, 4)).to.equal(true)
			expect(TrainingStopRules.isDone(state, 3)).to.equal(true)
			expect(state.finished).to.equal(false)
			-- The hide stop is an escape: walking on does not pass it, getting away does.
			expect(TrainingStopRules.enter(state, 5)).to.equal(false)
			expect(TrainingStopRules.complete(state, 4, "escape")).to.equal(true)
			expect(TrainingStopRules.enter(state, 5)).to.equal(true)
			expect(state.finished).to.equal(true)
			expect(TrainingStopRules.enter(state, 6)).to.equal(false)
		end)
	end)

	describe("openDoors", function()
		it("lists the doors whose stop is done", function()
			local state = TrainingStopRules.new()
			expect(#TrainingStopRules.openDoors(state)).to.equal(0)
			TrainingStopRules.complete(state, 1, "piles")
			local open = TrainingStopRules.openDoors(state)
			expect(#open).to.equal(1)
			expect(open[1]).to.equal(1)
		end)
	end)

	describe("escapeStep", function()
		local function sense(over)
			local base = { near = false, chasing = false, hidden = false, seen = true, far = false }
			for key, value in over do
				base[key] = value
			end
			return base
		end
		local seconds = TrainingConstants.ESCAPE.seconds

		it("passes once he came close and the player stayed hidden from him, away from him", function()
			local escape = TrainingStopRules.newEscape()
			expect(TrainingStopRules.escapeStep(escape, 1, sense({ near = true, hidden = true }))).to.equal(false)
			expect(TrainingStopRules.escapeStep(escape, seconds / 2, sense({ hidden = true, seen = false }))).to.equal(
				false
			)
			expect(TrainingStopRules.escapeStep(escape, seconds, sense({ hidden = true, seen = false }))).to.equal(true)
		end)

		it("passes when the player outruns him: far ahead, or out of his sight", function()
			local escape = TrainingStopRules.newEscape()
			TrainingStopRules.escapeStep(escape, 0.2, sense({ chasing = true, near = true }))
			expect(TrainingStopRules.escapeStep(escape, seconds + 0.1, sense({ far = true }))).to.equal(true)
			local other = TrainingStopRules.newEscape()
			TrainingStopRules.escapeStep(other, 0.2, sense({ chasing = true }))
			expect(TrainingStopRules.escapeStep(other, seconds + 0.1, sense({ seen = false }))).to.equal(true)
		end)

		it("never passes while he still chases the player or stands close", function()
			local escape = TrainingStopRules.newEscape()
			TrainingStopRules.escapeStep(escape, 0.2, sense({ near = true }))
			expect(TrainingStopRules.escapeStep(escape, 10, sense({ chasing = true, far = true }))).to.equal(false)
			expect(TrainingStopRules.escapeStep(escape, 10, sense({ near = true, hidden = true }))).to.equal(false)
		end)

		it("starts the safe count again when he comes back", function()
			local escape = TrainingStopRules.newEscape()
			TrainingStopRules.escapeStep(escape, 0.2, sense({ near = true }))
			TrainingStopRules.escapeStep(escape, seconds - 0.1, sense({ far = true }))
			TrainingStopRules.escapeStep(escape, 0.1, sense({ near = true }))
			expect(TrainingStopRules.escapeStep(escape, seconds - 0.1, sense({ far = true }))).to.equal(false)
		end)

		it("passes after a while if he never comes, so nobody is stuck", function()
			local escape = TrainingStopRules.newEscape()
			expect(TrainingStopRules.escapeStep(escape, TrainingConstants.ESCAPE.timeout - 1, sense({ far = true }))).to.equal(
				false
			)
			expect(TrainingStopRules.escapeStep(escape, 2, sense({ far = true }))).to.equal(true)
		end)
	end)
end
