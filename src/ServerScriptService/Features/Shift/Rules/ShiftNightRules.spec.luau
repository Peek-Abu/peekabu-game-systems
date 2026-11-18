local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftNightConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftNightConstants)
local ShiftNightFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftNightFormulas)
local ShiftNightRules = require(script.Parent.ShiftNightRules)

local function state(phase, tier)
	return {
		phase = phase,
		sub = "normal",
		stage = "normal",
		tier = tier or 0,
		shift = 1,
		quota = 100,
		quotaMet = false,
		variant = "A",
	}
end

return function()
	local N = ShiftNightConstants.WEEK_NIGHTS

	describe("parseMode", function()
		it("reads the two modes", function()
			expect(ShiftNightRules.parseMode(ShiftNightConstants.MODE_NIGHT)).to.equal("night")
			expect(ShiftNightRules.parseMode(ShiftNightConstants.MODE_QUICK)).to.equal("quick")
		end)

		it("reads anything missing or unknown as the default mode", function()
			local default = ShiftNightConstants.DEFAULT_MODE
			expect(ShiftNightRules.parseMode(nil)).to.equal(default)
			expect(ShiftNightRules.parseMode("floors")).to.equal(default)
			expect(ShiftNightRules.parseMode(3)).to.equal(default)
			expect(ShiftNightRules.parseMode(true)).to.equal(default)
			expect(ShiftNightRules.parseMode({})).to.equal(default)
			expect(ShiftNightRules.parseMode("QUICK")).to.equal(default)
		end)
	end)

	describe("weekQuota", function()
		it("is the week's goals: those already played plus this goal for each night left", function()
			expect(ShiftNightRules.weekQuota(0, 50, 1)).to.equal(50 * N)
			expect(ShiftNightRules.weekQuota(50, 60, 2)).to.equal(50 + 60 * (N - 1))
			expect(ShiftNightRules.weekQuota(110, 70, N)).to.equal(110 + 70)
		end)

		it("restarts with each week", function()
			expect(ShiftNightRules.weekQuota(0, 80, N + 1)).to.equal(80 * N)
		end)
	end)

	describe("settle", function()
		it("adds the night's clearance to the week mid-week, with no bonus and the run going on", function()
			local result = ShiftNightRules.settle({ night = 1, weekCleared = 0, weekQuota = 300, cleared = 120 })
			expect(result.weekCleared).to.equal(120)
			expect(result.bonus).to.equal(0)
			expect(result.newWeek).to.equal(false)
			expect(result.runOver).to.equal(nil)
		end)

		it("pays the week bonus and starts a new week when the weekly quota is met on its last night", function()
			local result = ShiftNightRules.settle({ night = N, weekCleared = 200, weekQuota = 300, cleared = 100 })
			expect(result.weekCleared).to.equal(300)
			expect(result.bonus).to.equal(ShiftNightFormulas.weekBonus(1))
			expect(result.newWeek).to.equal(true)
			expect(result.runOver).to.equal(nil)
		end)

		it("pays a later week's bigger bonus", function()
			local result = ShiftNightRules.settle({ night = 2 * N, weekCleared = 500, weekQuota = 400, cleared = 0 })
			expect(result.bonus).to.equal(ShiftNightFormulas.weekBonus(2))
		end)

		it("fires the crew when the weekly quota is missed on its last night", function()
			local result = ShiftNightRules.settle({ night = N, weekCleared = 100, weekQuota = 300, cleared = 50 })
			expect(result.weekCleared).to.equal(150)
			expect(result.bonus).to.equal(0)
			expect(result.newWeek).to.equal(false)
			expect(result.runOver).to.equal("fired")
		end)

		it("ends the run on a wipe", function()
			local result =
				ShiftNightRules.settle({ night = 1, weekCleared = 0, weekQuota = 300, cleared = 40, wiped = true })
			expect(result.runOver).to.equal("wiped")
			expect(result.weekCleared).to.equal(40)
		end)

		it("still pays a met week on a wipe, and calls a missed one fired", function()
			local met =
				ShiftNightRules.settle({ night = N, weekCleared = 250, weekQuota = 300, cleared = 60, wiped = true })
			expect(met.bonus).to.equal(ShiftNightFormulas.weekBonus(1))
			expect(met.runOver).to.equal("wiped")
			local missed =
				ShiftNightRules.settle({ night = N, weekCleared = 0, weekQuota = 300, cleared = 60, wiped = true })
			expect(missed.bonus).to.equal(0)
			expect(missed.runOver).to.equal("fired")
		end)

		it("never counts a negative clearance", function()
			local result = ShiftNightRules.settle({ night = 1, weekCleared = 10, weekQuota = 300, cleared = -5 })
			expect(result.weekCleared).to.equal(10)
		end)
	end)

	describe("minTier", function()
		it("is the night's start tier in Night Shift", function()
			expect(ShiftNightRules.minTier("night", N + 1, false)).to.equal(
				ShiftNightFormulas.startTier(N + 1, ShiftConstants.TOP_TIER)
			)
			expect(ShiftNightRules.minTier("night", 1, false)).to.equal(0)
		end)

		it("is 0 in a quick shift, in training and with no night", function()
			expect(ShiftNightRules.minTier("quick", 10, false)).to.equal(0)
			expect(ShiftNightRules.minTier("night", 10, true)).to.equal(0)
			expect(ShiftNightRules.minTier("night", nil, false)).to.equal(0)
		end)
	end)

	describe("stamp", function()
		local view = {
			runMode = "night",
			night = N + 1,
			week = 2,
			weekQuota = 600,
			weekCleared = 120,
		}

		it("copies the run's fields onto the state without changing the original", function()
			local before = state("results")
			local stamped = ShiftNightRules.stamp(before, view, false)
			expect(stamped.runMode).to.equal("night")
			expect(stamped.night).to.equal(N + 1)
			expect(stamped.week).to.equal(2)
			expect(stamped.weekQuota).to.equal(600)
			expect(stamped.weekCleared).to.equal(120)
			expect(stamped.runOver).to.equal(nil)
			expect(before.runMode).to.equal(nil)
		end)

		it("carries the run-over reason and the night reached", function()
			local over = table.clone(view)
			over.runOver = "fired"
			over.nightReached = N
			local stamped = ShiftNightRules.stamp(state("results"), over, false)
			expect(stamped.runOver).to.equal("fired")
			expect(stamped.nightReached).to.equal(N)
		end)

		it("raises a running night's tier to the night's start tier, never lowers it", function()
			local start = ShiftNightFormulas.startTier(N + 1, ShiftConstants.TOP_TIER)
			expect(ShiftNightRules.stamp(state("running", 0), view, false).tier).to.equal(start)
			expect(ShiftNightRules.stamp(state("running", ShiftConstants.TOP_TIER), view, false).tier).to.equal(
				ShiftConstants.TOP_TIER
			)
			expect(ShiftNightRules.stamp(state("results", 0), view, false).tier).to.equal(0)
		end)

		it("leaves a training run's tier alone", function()
			expect(ShiftNightRules.stamp(state("running", 0), view, true).tier).to.equal(0)
		end)

		it("clears the night fields for a quick shift", function()
			local before = state("running")
			before.night = 4
			before.weekQuota = 10
			local stamped = ShiftNightRules.stamp(before, { runMode = "quick" }, false)
			expect(stamped.runMode).to.equal("quick")
			expect(stamped.night).to.equal(nil)
			expect(stamped.weekQuota).to.equal(nil)
			expect(stamped.tier).to.equal(0)
		end)
	end)
end
