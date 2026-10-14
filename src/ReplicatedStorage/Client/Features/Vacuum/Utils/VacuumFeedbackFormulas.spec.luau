local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumFeedbackFormulas = require(script.Parent.VacuumFeedbackFormulas)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

return function()
	describe("whine", function()
		it("rises from the low pitch and volume to the high ones as the pile empties", function()
			local lowPitch, lowVolume = VacuumFeedbackFormulas.whine(0)
			local highPitch, highVolume = VacuumFeedbackFormulas.whine(1)
			expect(lowPitch).to.be.near(VacuumConstants.WHINE_PITCH_MIN, 1e-6)
			expect(lowVolume).to.be.near(VacuumConstants.WHINE_VOLUME_MIN, 1e-6)
			expect(highPitch).to.be.near(VacuumConstants.WHINE_PITCH_MAX, 1e-6)
			expect(highVolume).to.be.near(VacuumConstants.WHINE_VOLUME_MAX, 1e-6)
			local midPitch = VacuumFeedbackFormulas.whine(0.5)
			expect(midPitch > lowPitch and midPitch < highPitch).to.equal(true)
		end)

		it("clamps progress outside 0..1", function()
			expect(VacuumFeedbackFormulas.whine(-1)).to.be.near(VacuumConstants.WHINE_PITCH_MIN, 1e-6)
			expect(VacuumFeedbackFormulas.whine(3)).to.be.near(VacuumConstants.WHINE_PITCH_MAX, 1e-6)
		end)
	end)

	describe("cleared", function()
		it("pops a pile that was being vacuumed past half, even after its progress was cleared", function()
			expect(VacuumFeedbackFormulas.cleared(0.97, 0)).to.equal(true)
			expect(VacuumFeedbackFormulas.cleared(VacuumConstants.POP_PROGRESS, VacuumConstants.POP_WINDOW)).to.equal(
				true
			)
		end)

		it("does not pop a pile removed by a reset", function()
			expect(VacuumFeedbackFormulas.cleared(0, 100)).to.equal(false)
			expect(VacuumFeedbackFormulas.cleared(0.8, 30)).to.equal(false)
		end)

		it("does not pop a barely-touched pile", function()
			expect(VacuumFeedbackFormulas.cleared(0.2, 0)).to.equal(false)
		end)
	end)

	describe("canisterCue", function()
		it("ticks when a pile goes in", function()
			expect(VacuumFeedbackFormulas.canisterCue(0, 1, 3, true)).to.equal("fill")
			expect(VacuumFeedbackFormulas.canisterCue(1, 2, 3, true)).to.equal("fill")
		end)

		it("chimes when the last pile pops a dust bag", function()
			expect(VacuumFeedbackFormulas.canisterCue(2, 0, 3, true)).to.equal("full")
		end)

		it("never chimes outside a running shift (a reset empties the canister)", function()
			expect(VacuumFeedbackFormulas.canisterCue(2, 0, 3, false)).to.equal(nil)
			expect(VacuumFeedbackFormulas.canisterCue(0, 1, 3, false)).to.equal(nil)
		end)

		it("says nothing for an emptied canister that was not about to pop", function()
			expect(VacuumFeedbackFormulas.canisterCue(1, 0, 3, true)).to.equal(nil)
			expect(VacuumFeedbackFormulas.canisterCue(1, 1, 3, true)).to.equal(nil)
		end)
	end)

	describe("nearest", function()
		it("picks the closest point within range", function()
			local points = { Vector3.new(9, 0, 0), Vector3.new(3, 0, 0), Vector3.new(0, 0, 20) }
			expect(VacuumFeedbackFormulas.nearest(Vector3.zero, points, 10)).to.equal(2)
		end)

		it("is nil when nobody is in range", function()
			expect(VacuumFeedbackFormulas.nearest(Vector3.zero, { Vector3.new(50, 0, 0) }, 10)).to.equal(nil)
			expect(VacuumFeedbackFormulas.nearest(Vector3.zero, {}, 10)).to.equal(nil)
		end)
	end)

	describe("gauge", function()
		it("shows the canister's share of its capacity", function()
			expect(VacuumFeedbackFormulas.gaugeTarget(0, 3, 0, 10)).to.equal(0)
			expect(VacuumFeedbackFormulas.gaugeTarget(2, 3, 0, 10)).to.be.near(2 / 3, 1e-9)
			expect(VacuumFeedbackFormulas.gaugeTarget(5, 3, 0, 10)).to.equal(1)
		end)

		it("shows full while a just-filled canister holds before it drains into the dust bag", function()
			expect(VacuumFeedbackFormulas.gaugeTarget(0, 3, 11, 10)).to.equal(1)
			expect(VacuumFeedbackFormulas.gaugeTarget(0, 3, 11, 11.5)).to.equal(0)
		end)

		it("eases toward its target without overshooting and settles on it", function()
			local shown = VacuumFeedbackFormulas.gaugeStep(0, 1, 1 / 60, 6)
			expect(shown > 0 and shown < 0.2).to.equal(true)
			expect(VacuumFeedbackFormulas.gaugeStep(0.999, 1, 1 / 60, 6)).to.equal(1)
			expect(VacuumFeedbackFormulas.gaugeStep(0.5, 0, 10, 6)).to.equal(0)
		end)

		it("rises from the bottom: the insert's height and how far its centre drops", function()
			local height, drop = VacuumFeedbackFormulas.gaugeFill(0.5, 0.4)
			expect(height).to.be.near(0.2, 1e-9)
			expect(drop).to.be.near(0.15, 1e-9)
			local empty, emptyDrop = VacuumFeedbackFormulas.gaugeFill(0.5, -1)
			expect(empty).to.equal(0)
			expect(emptyDrop).to.be.near(0.25, 1e-9)
		end)
	end)
end
