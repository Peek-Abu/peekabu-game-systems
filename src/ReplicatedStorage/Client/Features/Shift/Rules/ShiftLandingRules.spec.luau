local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftLandingRules = require(script.Parent.ShiftLandingRules)
local ShiftAssets = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftAssets)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)

local TIMING = ShiftLandingRules.TIMING
local SLOT = TIMING.fadeIn + TIMING.hold + TIMING.fadeOut
local PITCH = SLOT + TIMING.gap

return function()
	describe("shows", function()
		it("shows on an arrival at a shift", function()
			expect(ShiftLandingRules.shows({ hub = false, client = "Harlow & Finch Ltd." })).to.equal(true)
			expect(ShiftLandingRules.shows({ hub = false, client = nil })).to.equal(true)
		end)

		it("never shows in the hub", function()
			expect(ShiftLandingRules.shows({ hub = true, client = "Harlow & Finch Ltd." })).to.equal(false)
		end)

		it("never shows in training", function()
			expect(ShiftLandingRules.shows({ hub = false, client = TrainingConstants.CONTRACT.client })).to.equal(false)
		end)
	end)

	describe("seedOf", function()
		it("uses the built office's layout seed", function()
			expect(ShiftLandingRules.seedOf({ userId = 1, id = 5, built = true, seed = 9001 })).to.equal(9001)
		end)

		it("falls back on the hold's id, which the whole crew shares, when the office has no seed", function()
			expect(ShiftLandingRules.seedOf({ userId = 1, id = 5, built = true })).to.equal(5)
		end)
	end)

	describe("watch", function()
		it("notes when the arrival card first shows", function()
			local state = ShiftLandingRules.watch({}, true, 10)
			expect(state.seenAt).to.equal(10)
			expect(state.closedAt).to.equal(nil)
			state = ShiftLandingRules.watch(state, true, 11)
			expect(state.seenAt).to.equal(10)
		end)

		it("notes when the arrival card closes", function()
			local state = ShiftLandingRules.watch({}, true, 10)
			state = ShiftLandingRules.watch(state, false, 15)
			expect(state.seenAt).to.equal(10)
			expect(state.closedAt).to.equal(15)
			state = ShiftLandingRules.watch(state, false, 16)
			expect(state.closedAt).to.equal(15)
		end)

		it("notes nothing while no arrival card has shown", function()
			local state = ShiftLandingRules.watch({}, false, 10)
			expect(state.seenAt).to.equal(nil)
			expect(state.closedAt).to.equal(nil)
		end)
	end)

	describe("startAt", function()
		it("starts a short beat after the arrival card closes", function()
			local start = ShiftLandingRules.startAt({ revealAt = 100, now = 106, seenAt = 99, closedAt = 106 })
			expect(start).to.equal(106 + TIMING.beat)
			expect(TIMING.beat > 0 and TIMING.beat <= 1).to.equal(true)
		end)

		it("waits while the arrival card is up", function()
			expect(ShiftLandingRules.startAt({ revealAt = 100, now = 104, seenAt = 99 })).to.equal(nil)
		end)

		it("gives up waiting on a card that never closes", function()
			local now = 100 + TIMING.wait
			expect(ShiftLandingRules.startAt({ revealAt = 100, now = now, seenAt = 99 })).to.equal(now)
			expect(TIMING.wait > ShiftConstants.TRANSIT_ARRIVED_SECONDS + 5).to.equal(true)
		end)

		it("falls back on the reveal when no arrival card shows (a late joiner)", function()
			expect(TIMING.fallback >= ShiftConstants.TRANSIT_ARRIVED_SECONDS + ShiftConstants.TRANSIT_FADE_OUT).to.equal(
				true
			)
			expect(ShiftLandingRules.startAt({ revealAt = 100, now = 100 + TIMING.fallback - 0.01 })).to.equal(nil)
			expect(ShiftLandingRules.startAt({ revealAt = 100, now = 100 + TIMING.fallback })).to.equal(
				100 + TIMING.fallback
			)
		end)
	end)

	describe("screenAt", function()
		it("shows three screens, one at a time, in order", function()
			expect(ShiftLandingRules.SCREENS).to.equal(3)
			for index = 1, 3 do
				local mid = (index - 1) * PITCH + TIMING.fadeIn + TIMING.hold / 2
				local screen, alpha = ShiftLandingRules.screenAt(mid)
				expect(screen).to.equal(index)
				expect(alpha).to.equal(1)
			end
		end)

		it("tweens each screen in, holds it about two seconds, then tweens it out", function()
			local screen, alpha = ShiftLandingRules.screenAt(TIMING.fadeIn / 2)
			expect(screen).to.equal(1)
			expect(alpha > 0 and alpha < 1).to.equal(true)
			screen, alpha = ShiftLandingRules.screenAt(TIMING.fadeIn + TIMING.hold + TIMING.fadeOut / 2)
			expect(screen).to.equal(1)
			expect(alpha > 0 and alpha < 1).to.equal(true)
			expect(TIMING.hold >= 1.5 and TIMING.hold <= 2.5).to.equal(true)
		end)

		it("shows nothing between screens, before the start and after the last", function()
			local screen = ShiftLandingRules.screenAt(SLOT + TIMING.gap / 2)
			expect(screen).to.equal(0)
			expect((ShiftLandingRules.screenAt(-1))).to.equal(0)
			expect((ShiftLandingRules.screenAt(0 / 0))).to.equal(0)
			expect((ShiftLandingRules.screenAt(ShiftLandingRules.total()))).to.equal(0)
		end)

		it("is over once the last screen has gone", function()
			expect(ShiftLandingRules.total()).to.equal(3 * PITCH - TIMING.gap)
			expect(ShiftLandingRules.over(ShiftLandingRules.total() - 0.01)).to.equal(false)
			expect(ShiftLandingRules.over(ShiftLandingRules.total())).to.equal(true)
		end)

		it("plays a fourth screen when given four (a Night Shift's NIGHT n / WEEK w first)", function()
			expect(ShiftLandingRules.total(4)).to.equal(4 * PITCH - TIMING.gap)
			local mid = 3 * PITCH + TIMING.fadeIn + TIMING.hold / 2
			local screen, alpha = ShiftLandingRules.screenAt(mid, 4)
			expect(screen).to.equal(4)
			expect(alpha).to.equal(1)
			expect((ShiftLandingRules.screenAt(mid))).to.equal(0)
			expect(ShiftLandingRules.over(mid, 4)).to.equal(false)
			expect(ShiftLandingRules.over(mid)).to.equal(true)
		end)
	end)

	-- Owner Night Shift pick 2026-11-18 (night start A): the night sting plays as NIGHT n / WEEK w comes up.
	describe("nightSting", function()
		it("plays once, as a Night Shift's first screen (NIGHT n / WEEK w) comes up", function()
			expect(ShiftLandingRules.nightSting(0, 1, true)).to.equal(true)
			expect(ShiftLandingRules.nightSting(1, 1, true)).to.equal(false)
			expect(ShiftLandingRules.nightSting(1, 0, true)).to.equal(false)
			expect(ShiftLandingRules.nightSting(1, 2, true)).to.equal(false)
		end)

		it("stays quiet on a quick shift (its first screen is the weather)", function()
			expect(ShiftLandingRules.nightSting(0, 1, false)).to.equal(false)
		end)

		it("plays the picked night sting", function()
			expect(ShiftAssets.NIGHT_START).to.equal("shiftNightStart")
			expect(ShiftAssets.SOUNDS.shiftNightStart.assetId).to.equal("rbxassetid://117436012823674")
		end)
	end)
end
