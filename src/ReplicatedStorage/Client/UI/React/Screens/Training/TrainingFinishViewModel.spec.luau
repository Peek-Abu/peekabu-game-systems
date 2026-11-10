local TrainingFinishViewModel = require(script.Parent.TrainingFinishViewModel)

local function near(actual, expected)
	return math.abs(actual - expected) < 1e-3
end

return function()
	describe("canvas", function()
		it("is the 1920x1080 design on desktop and the 844x390 design on phone", function()
			expect(TrainingFinishViewModel.canvas(false)).to.equal(Vector2.new(1920, 1080))
			expect(TrainingFinishViewModel.canvas(true)).to.equal(Vector2.new(844, 390))
		end)
	end)

	describe("fit", function()
		it("draws the canvas at 1 when the area holds it", function()
			local fit = TrainingFinishViewModel.fit(Vector2.new(1920, 1080), false)
			expect(fit.scale).to.equal(1)
		end)

		it("never grows the canvas past 1 on a bigger area", function()
			expect(TrainingFinishViewModel.fit(Vector2.new(2400, 1300), false).scale).to.equal(1)
		end)

		-- The owner's cutoff: a short window (a laptop at the HUD's readable minimum, Studio's play pane) left
		-- less than 1080 design px, and the employee's feet were drawn past the screen's bottom.
		it("shrinks to the area's height on a short window, so the employee's feet stay on the screen", function()
			local fit = TrainingFinishViewModel.fit(Vector2.new(1820, 900), false)
			expect(near(fit.scale, 900 / 1080)).to.equal(true)
			expect(near(1080 * fit.scale, 900)).to.equal(true)
		end)

		it("shrinks to the area's width on a narrow window", function()
			local fit = TrainingFinishViewModel.fit(Vector2.new(1440, 1080), false)
			expect(near(fit.scale, 1440 / 1920)).to.equal(true)
		end)

		it("fits a phone smaller than the 844x390 design, by its tighter side", function()
			expect(near(TrainingFinishViewModel.fit(Vector2.new(667, 375), true).scale, 667 / 844)).to.equal(true)
			expect(near(TrainingFinishViewModel.fit(Vector2.new(800, 360), true).scale, 360 / 390)).to.equal(true)
		end)

		it("centres the scaled canvas in the area", function()
			local fit = TrainingFinishViewModel.fit(Vector2.new(2400, 900), false)
			local drawn = Vector2.new(1920, 1080) * fit.scale
			expect(near(fit.offset.X, (2400 - drawn.X) / 2)).to.equal(true)
			expect(near(fit.offset.Y, 0)).to.equal(true)
		end)

		it("keeps a sane scale for an empty area (not yet measured)", function()
			expect(TrainingFinishViewModel.fit(Vector2.zero, false).scale).to.equal(1)
		end)
	end)
end
