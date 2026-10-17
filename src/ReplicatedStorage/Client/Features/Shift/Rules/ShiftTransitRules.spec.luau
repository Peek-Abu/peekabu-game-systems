local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftTransitRules = require(script.Parent.ShiftTransitRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)

local SPOT = Vector3.new(100, 5, 50)

local function hold(extra)
	local value = { userId = 7, id = 3, built = true, seed = 42, spot = SPOT }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function input(extra)
	local value = {
		hold = hold(),
		shownFor = ShiftConstants.TRANSIT_MIN_SECONDS,
		seedSeen = true,
		position = SPOT + Vector3.new(0, 2, 0),
		streamed = true,
		lit = true,
		settledFor = ShiftConstants.TRANSIT_SETTLE_SECONDS,
		settledFrames = ShiftConstants.TRANSIT_SETTLE_FRAMES,
		cold = false,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("cover", function()
		it("shows the route slip while held", function()
			expect(ShiftTransitRules.cover({ held = true, booting = true, now = 0 })).to.equal("slip")
		end)

		it("is black while the client boots, and during a respawn blink", function()
			expect(ShiftTransitRules.cover({ held = false, booting = true, now = 0 })).to.equal("black")
			expect(ShiftTransitRules.cover({ held = false, booting = false, blinkUntil = 5, now = 4 })).to.equal(
				"black"
			)
		end)

		it("shows nothing otherwise", function()
			expect(ShiftTransitRules.cover({ held = false, booting = false, blinkUntil = 5, now = 5 })).to.equal("none")
			expect(ShiftTransitRules.cover({ held = false, booting = false, now = 0 })).to.equal("none")
		end)
	end)

	describe("verdict", function()
		it("is ready once everything is in", function()
			local verdict, reason = ShiftTransitRules.verdict(input())
			expect(verdict).to.equal("ready")
			expect(reason).to.equal(nil)
		end)

		it("waits for the office to be built and seen", function()
			local verdict, reason = ShiftTransitRules.verdict(input({ hold = hold({ built = false }) }))
			expect(verdict).to.equal("waiting")
			expect(reason).to.equal("office")
			verdict, reason = ShiftTransitRules.verdict(input({ seedSeen = false }))
			expect(reason).to.equal("office")
		end)

		it("waits for the character to stand on its spot", function()
			local _, far = ShiftTransitRules.verdict(input({ position = SPOT + Vector3.new(50, 0, 0) }))
			expect(far).to.equal("placed")
			local _, none = ShiftTransitRules.verdict(input({ position = false }))
			expect(none).to.equal("placed")
		end)

		it("waits for streaming, then the lighting, then the scene to settle, then the minimum time", function()
			local _, streamed = ShiftTransitRules.verdict(input({ streamed = false }))
			expect(streamed).to.equal("streamed")
			local _, lit = ShiftTransitRules.verdict(input({ lit = false }))
			expect(lit).to.equal("lighting")
			local _, settling = ShiftTransitRules.verdict(input({ settledFor = 0.2, shownFor = 0.2 }))
			expect(settling).to.equal("settling")
			local _, minimum = ShiftTransitRules.verdict(input({ shownFor = 0.2 }))
			expect(minimum).to.equal("minimum")
		end)

		it("waits until the scene has held still both long enough and for enough rendered frames", function()
			local _, short =
				ShiftTransitRules.verdict(input({ settledFor = ShiftConstants.TRANSIT_SETTLE_SECONDS - 0.1 }))
			expect(short).to.equal("settling")
			-- A slow client renders fewer frames in the same time: it waits for the frames too.
			local _, slow = ShiftTransitRules.verdict(input({
				settledFor = ShiftConstants.TRANSIT_SETTLE_SECONDS * 2,
				settledFrames = ShiftConstants.TRANSIT_SETTLE_FRAMES - 1,
			}))
			expect(slow).to.equal("settling")
			local verdict = ShiftTransitRules.verdict(input({
				settledFor = ShiftConstants.TRANSIT_SETTLE_SECONDS,
				settledFrames = ShiftConstants.TRANSIT_SETTLE_FRAMES,
			}))
			expect(verdict).to.equal("ready")
		end)

		it("settles longer when the camera arrived from far away (the first shift, from the depot)", function()
			local warm = {
				settledFor = ShiftConstants.TRANSIT_SETTLE_SECONDS,
				settledFrames = ShiftConstants.TRANSIT_SETTLE_FRAMES,
			}
			expect(ShiftTransitRules.verdict(input(warm))).to.equal("ready")
			warm.cold = true
			local _, reason = ShiftTransitRules.verdict(input(warm))
			expect(reason).to.equal("settling")
			local _, fewFrames = ShiftTransitRules.verdict(input({
				cold = true,
				settledFor = ShiftConstants.TRANSIT_COLD_SETTLE_SECONDS,
				settledFrames = ShiftConstants.TRANSIT_COLD_SETTLE_FRAMES - 1,
			}))
			expect(fewFrames).to.equal("settling")
			expect(ShiftTransitRules.verdict(input({
				cold = true,
				settledFor = ShiftConstants.TRANSIT_COLD_SETTLE_SECONDS,
				settledFrames = ShiftConstants.TRANSIT_COLD_SETTLE_FRAMES,
			}))).to.equal("ready")
			expect(ShiftConstants.TRANSIT_COLD_SETTLE_SECONDS > ShiftConstants.TRANSIT_SETTLE_SECONDS).to.equal(true)
		end)

		it("reports the scene's own missing condition, ignoring the settle and the minimum", function()
			expect(ShiftTransitRules.scene(input({ settledFor = 0, settledFrames = 0, shownFor = 0 }))).to.equal(nil)
			expect(ShiftTransitRules.scene(input({ lit = false }))).to.equal("lighting")
			expect(ShiftTransitRules.scene(input({ seedSeen = false }))).to.equal("office")
		end)

		it("times out with the reason it was still waiting for", function()
			local verdict, reason = ShiftTransitRules.verdict(input({
				streamed = false,
				shownFor = ShiftConstants.TRANSIT_CLIENT_TIMEOUT,
			}))
			expect(verdict).to.equal("timeout")
			expect(reason).to.equal("streamed")
		end)
	end)
end
