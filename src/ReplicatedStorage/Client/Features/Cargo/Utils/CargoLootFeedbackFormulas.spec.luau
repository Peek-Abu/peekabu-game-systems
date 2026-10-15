local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoLootFeedbackFormulas = require(script.Parent.CargoLootFeedbackFormulas)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)

return function()
	describe("grime look", function()
		it("is darkest when grimy and gone when clean", function()
			expect(CargoLootFeedbackFormulas.grimeFill(0)).to.be.near(CargoConstants.GRIME_FILL_TRANSPARENCY, 1e-9)
			expect(CargoLootFeedbackFormulas.grimeFill(1)).to.be.near(1, 1e-9)
			local half = CargoLootFeedbackFormulas.grimeFill(0.5)
			expect(half > CargoConstants.GRIME_FILL_TRANSPARENCY and half < 1).to.equal(true)
		end)

		it("sheds dust motes until clean", function()
			expect(CargoLootFeedbackFormulas.moteRate(0)).to.equal(CargoConstants.GRIME_MOTE_RATE)
			expect(CargoLootFeedbackFormulas.moteRate(1)).to.equal(0)
			expect(CargoLootFeedbackFormulas.moteRate(2)).to.equal(0)
		end)

		it("is drawn near the camera, never while buried, and not once clean", function()
			expect(CargoLootFeedbackFormulas.grimeShown(10, false, 0.2)).to.equal(true)
			expect(CargoLootFeedbackFormulas.grimeShown(10, true, 0.2)).to.equal(false)
			expect(CargoLootFeedbackFormulas.grimeShown(10, false, 1)).to.equal(false)
			expect(CargoLootFeedbackFormulas.grimeShown(CargoConstants.GRIME_VISUAL_DISTANCE + 1, false, 0)).to.equal(
				false
			)
		end)
	end)

	describe("glint", function()
		it("waits a random interval between the configured bounds", function()
			expect(CargoLootFeedbackFormulas.glintDelay(0)).to.equal(CargoConstants.GLINT_INTERVAL_MIN)
			expect(CargoLootFeedbackFormulas.glintDelay(1)).to.equal(CargoConstants.GLINT_INTERVAL_MAX)
		end)

		it("is only seen up close", function()
			expect(CargoLootFeedbackFormulas.glintSeen(CargoConstants.GLINT_DISTANCE)).to.equal(true)
			expect(CargoLootFeedbackFormulas.glintSeen(CargoConstants.GLINT_DISTANCE + 0.5)).to.equal(false)
		end)
	end)

	describe("stamp", function()
		it("pops only while the appraisal is fresh", function()
			expect(CargoLootFeedbackFormulas.stampFresh(10, 11)).to.equal(true)
			expect(CargoLootFeedbackFormulas.stampFresh(10, 10 + CargoConstants.STAMP_FRESH_SECONDS + 0.1)).to.equal(
				false
			)
			expect(CargoLootFeedbackFormulas.stampFresh(nil, 11)).to.equal(false)
		end)
	end)
end
