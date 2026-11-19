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

	describe("settle", function()
		it("goes on after a met night mid-week, with no bonus", function()
			local result = ShiftNightRules.settle({ night = 1, met = true })
			expect(result.bonus).to.equal(0)
			expect(result.runOver).to.equal(nil)
		end)

		it("fires the crew on any night that misses its goal", function()
			for _, night in { 1, 2, N, N + 3 } do
				local result = ShiftNightRules.settle({ night = night, met = false })
				expect(result.runOver).to.equal("fired")
				expect(result.bonus).to.equal(0)
			end
		end)

		it("pays the week bonus for surviving the week's last night", function()
			local result = ShiftNightRules.settle({ night = N, met = true })
			expect(result.bonus).to.equal(ShiftNightFormulas.weekBonus(1))
			expect(result.runOver).to.equal(nil)
		end)

		it("pays a later week's bigger bonus", function()
			local result = ShiftNightRules.settle({ night = 2 * N, met = true })
			expect(result.bonus).to.equal(ShiftNightFormulas.weekBonus(2))
		end)

		it("ends the run on a wipe, met or not, with no bonus", function()
			local missed = ShiftNightRules.settle({ night = 1, met = false, wiped = true })
			expect(missed.runOver).to.equal("wiped")
			local lastNight = ShiftNightRules.settle({ night = N, met = true, wiped = true })
			expect(lastNight.runOver).to.equal("wiped")
			expect(lastNight.bonus).to.equal(0)
		end)
	end)

	describe("extraTime", function()
		local function close(changes)
			local input = { night = 3, training = false, used = false, quota = 200, cleared = 160, quotaMet = false }
			for key, value in changes or {} do
				input[key] = value
			end
			return input
		end

		it("gives a Night Shift crew close to tonight's goal extra time", function()
			expect(ShiftNightRules.extraTime(close())).to.equal(ShiftNightConstants.EXTRA_TIME_SECONDS)
			expect(ShiftNightRules.extraTime(close({ cleared = 199 }))).to.equal(ShiftNightConstants.EXTRA_TIME_SECONDS)
		end)

		it("gives none to a crew far from the goal", function()
			expect(ShiftNightRules.extraTime(close({ cleared = 159 }))).to.equal(0)
			expect(ShiftNightRules.extraTime(close({ cleared = 0 }))).to.equal(0)
		end)

		it("gives it only once a night", function()
			expect(ShiftNightRules.extraTime(close({ used = true }))).to.equal(0)
		end)

		it("gives none once the goal is met, in a quick shift or in training", function()
			expect(ShiftNightRules.extraTime(close({ quotaMet = true }))).to.equal(0)
			-- A nil in `close`'s changes would be skipped, so a quick shift's input clears the night by hand.
			local quick = close()
			quick.night = nil
			expect(ShiftNightRules.extraTime(quick)).to.equal(0)
			expect(ShiftNightRules.extraTime(close({ training = true }))).to.equal(0)
			expect(ShiftNightRules.extraTime(close({ quota = 0, cleared = 0 }))).to.equal(0)
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
		}

		it("copies the run's fields onto the state without changing the original", function()
			local before = state("results")
			local stamped = ShiftNightRules.stamp(before, view, false)
			expect(stamped.runMode).to.equal("night")
			expect(stamped.night).to.equal(N + 1)
			expect(stamped.week).to.equal(2)
			expect(stamped.weekBonus).to.equal(nil)
			expect(stamped.runOver).to.equal(nil)
			expect(before.runMode).to.equal(nil)
		end)

		it("carries the week report's bonus", function()
			local report = table.clone(view)
			report.weekBonus = 150
			expect(ShiftNightRules.stamp(state("results"), report, false).weekBonus).to.equal(150)
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
			before.weekBonus = 10
			local stamped = ShiftNightRules.stamp(before, { runMode = "quick" }, false)
			expect(stamped.runMode).to.equal("quick")
			expect(stamped.night).to.equal(nil)
			expect(stamped.weekBonus).to.equal(nil)
			expect(stamped.tier).to.equal(0)
		end)
	end)
end
