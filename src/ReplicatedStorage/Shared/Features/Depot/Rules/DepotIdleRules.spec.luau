local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotIdleRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotIdleRules)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)

local IDLE = DepotSpotConstants.IDLE

return function()
	describe("nextAt", function()
		it("waits between the motion's interval bounds", function()
			local range = IDLE.INTERVALS.steam
			expect(DepotIdleRules.nextAt(10, "steam", 0)).to.equal(10 + range[1])
			expect(DepotIdleRules.nextAt(10, "steam", 1)).to.equal(10 + range[2])
		end)

		it("never waits for a motion that always runs (bounce, tick)", function()
			expect(DepotIdleRules.nextAt(10, "tick", 0.5)).to.equal(10)
		end)
	end)

	describe("bounce", function()
		local beat = IDLE.BEAT_SECONDS
		it("hops up on the beat and settles before the next", function()
			expect(DepotIdleRules.bounce(0, beat)).to.be.near(0, 1e-6)
			local peak = DepotIdleRules.bounce(beat * IDLE.BOUNCE.SHARE / 2, beat)
			expect(peak).to.be.near(IDLE.BOUNCE.APEX, 1e-6)
			expect(DepotIdleRules.bounce(beat * 0.9, beat)).to.equal(0)
			expect(DepotIdleRules.bounce(beat + beat * IDLE.BOUNCE.SHARE / 2, beat)).to.be.near(IDLE.BOUNCE.APEX, 1e-6)
		end)
	end)

	describe("rattle", function()
		it("jiggles a few degrees and dies down", function()
			expect(DepotIdleRules.rattle(0)).to.equal(0)
			for t = 0, IDLE.RATTLE.SECONDS, 0.02 do
				expect(math.abs(DepotIdleRules.rattle(t)) <= IDLE.RATTLE.DEGREES + 1e-6).to.equal(true)
			end
			expect(DepotIdleRules.rattle(IDLE.RATTLE.SECONDS + 0.01)).to.equal(0)
		end)
	end)

	describe("sway", function()
		it("nudges a little and comes to rest", function()
			for t = 0, IDLE.SWAY.SECONDS, 0.05 do
				expect(math.abs(DepotIdleRules.sway(t)) <= IDLE.SWAY.DEGREES + 1e-6).to.equal(true)
			end
			expect(DepotIdleRules.sway(IDLE.SWAY.SECONDS)).to.equal(0)
		end)
	end)

	describe("tick", function()
		it("steps the second hand 6 degrees a second, clockwise, round the minute", function()
			expect(DepotIdleRules.tick(0)).to.equal(0)
			expect(DepotIdleRules.tick(1.4)).to.equal(-6)
			expect(DepotIdleRules.tick(59.9)).to.equal(-354)
			expect(DepotIdleRules.tick(60.2)).to.equal(0)
		end)
	end)

	describe("vend", function()
		local VEND = IDLE.VEND
		it("nudges the item forward off its shelf first, without falling", function()
			local forward, fallen, tip, done = DepotIdleRules.vend(VEND.PUSH_SECONDS / 2, 3)
			expect(forward > 0 and forward < VEND.PUSH).to.equal(true)
			expect(fallen).to.equal(0)
			expect(tip).to.equal(0)
			expect(done).to.equal(false)
		end)
		it(
			"then drops it to the tray, faster and faster, tipping forward as it goes, never spinning past the tip",
			function()
				local push = VEND.PUSH_SECONDS
				local _, a = DepotIdleRules.vend(push + 0.05, 3)
				local _, b = DepotIdleRules.vend(push + 0.1, 3)
				local _, c = DepotIdleRules.vend(push + 0.15, 3)
				expect(c - b > b - a).to.equal(true)
				local forward, fallen, tip, done = DepotIdleRules.vend(push + 10, 3)
				expect(forward).to.equal(VEND.PUSH)
				expect(fallen).to.equal(3)
				expect(tip).to.equal(VEND.TIP)
				expect(done).to.equal(true)
				local _, _, midTip = DepotIdleRules.vend(push + 0.1, 3)
				expect(midTip > 0 and midTip < VEND.TIP).to.equal(true)
			end
		)
		it("lands at once from a shelf already at the tray", function()
			local _, fallen, _, done = DepotIdleRules.vend(VEND.PUSH_SECONDS + 0.01, 0)
			expect(fallen).to.equal(0)
			expect(done).to.equal(true)
		end)
	end)

	describe("fall", function()
		it("falls faster and faster and stops at the bottom", function()
			local early = DepotIdleRules.fall(0.05)
			local later = DepotIdleRules.fall(0.15)
			expect(later - DepotIdleRules.fall(0.1) > DepotIdleRules.fall(0.1) - early).to.equal(true)
			expect(DepotIdleRules.fall(10)).to.equal(IDLE.FALL.DISTANCE)
			expect(DepotIdleRules.fallDone(10)).to.equal(true)
			expect(DepotIdleRules.fallDone(0)).to.equal(false)
		end)
	end)
end
