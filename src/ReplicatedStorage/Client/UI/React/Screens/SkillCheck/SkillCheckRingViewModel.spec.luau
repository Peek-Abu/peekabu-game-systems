local SkillCheckRingViewModel = require(script.Parent.SkillCheckRingViewModel)

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

return function()
	describe("fraction", function()
		it("runs 0 at the ring's start to 1 at its arrival", function()
			expect(SkillCheckRingViewModel.fraction(8.8, 10, 1.2)).to.equal(0)
			expect(near(SkillCheckRingViewModel.fraction(9.4, 10, 1.2), 0.5)).to.equal(true)
			expect(SkillCheckRingViewModel.fraction(10, 10, 1.2)).to.equal(1)
		end)

		it("clamps before the start and after the arrival", function()
			expect(SkillCheckRingViewModel.fraction(5, 10, 1.2)).to.equal(0)
			expect(SkillCheckRingViewModel.fraction(12, 10, 1.2)).to.equal(1)
		end)

		it("is arrived for a travel of zero", function()
			expect(SkillCheckRingViewModel.fraction(9, 10, 0)).to.equal(1)
		end)
	end)

	describe("outerRadius", function()
		it("closes from the start radius onto the inner circle", function()
			for _, layout in { "desktop", "phone" } do
				local metrics = SkillCheckRingViewModel.METRICS[layout]
				expect(SkillCheckRingViewModel.outerRadius(layout, 0)).to.equal(metrics.outerStart)
				expect(SkillCheckRingViewModel.outerRadius(layout, 1)).to.equal(metrics.inner)
				local mid = SkillCheckRingViewModel.outerRadius(layout, 0.5)
				expect(mid < metrics.outerStart and mid > metrics.inner).to.equal(true)
			end
		end)

		it("is smaller on a phone", function()
			local desktop = SkillCheckRingViewModel.METRICS.desktop
			local phone = SkillCheckRingViewModel.METRICS.phone
			expect(phone.outerStart < desktop.outerStart).to.equal(true)
			expect(phone.inner < desktop.inner).to.equal(true)
		end)
	end)

	describe("beads", function()
		it("lays the beads evenly round the circle from straight up", function()
			local beads = SkillCheckRingViewModel.beads(8, 180, 10)
			expect(#beads).to.equal(8)
			expect(beads[1].angle).to.equal(0)
			expect(beads[3].angle).to.equal(90)
		end)

		it("marks the beads inside the opening", function()
			local beads = SkillCheckRingViewModel.beads(8, 90, 100)
			-- 40..140 holds the 45, 90 and 135 beads.
			local open = {}
			for _, bead in beads do
				if bead.open then
					table.insert(open, bead.angle)
				end
			end
			expect(#open).to.equal(3)
			expect(open[1]).to.equal(45)
			expect(open[3]).to.equal(135)
		end)

		it("marks beads across 0/360", function()
			local beads = SkillCheckRingViewModel.beads(8, 0, 100)
			expect(beads[1].open).to.equal(true)
			expect(beads[2].open).to.equal(true)
			expect(beads[8].open).to.equal(true)
			expect(beads[5].open).to.equal(false)
		end)

		it("always leaves at least one bead open, however narrow the opening", function()
			local beads = SkillCheckRingViewModel.beads(8, 20, 2)
			local count = 0
			for _, bead in beads do
				if bead.open then
					count += 1
				end
			end
			expect(count >= 1).to.equal(true)
		end)
	end)

	describe("place", function()
		it("puts angle 0 straight above the centre and 90 to its right", function()
			local up = SkillCheckRingViewModel.place(0, 10)
			expect(near(up.X, 0)).to.equal(true)
			expect(near(up.Y, -10)).to.equal(true)
			local right = SkillCheckRingViewModel.place(90, 10)
			expect(near(right.X, 10)).to.equal(true)
			expect(near(right.Y, 0)).to.equal(true)
		end)
	end)

	describe("centre", function()
		it("sits on the screen's middle line, a little below centre, inside the screen", function()
			for _, case in { { "desktop", Vector2.new(1920, 1080) }, { "phone", Vector2.new(844, 390) } } do
				local layout, viewport = case[1], case[2]
				local centre = SkillCheckRingViewModel.centre(layout, viewport)
				local outer = SkillCheckRingViewModel.METRICS[layout].outerStart
				expect(centre.X).to.equal(viewport.X / 2)
				expect(centre.Y >= viewport.Y / 2).to.equal(true)
				expect(centre.Y + outer <= viewport.Y).to.equal(true)
				expect(centre.Y - outer >= 0).to.equal(true)
			end
		end)
	end)

	describe("flash", function()
		it("starts full and fades out", function()
			expect(SkillCheckRingViewModel.flash(0)).to.equal(1)
			local mid = SkillCheckRingViewModel.flash(SkillCheckRingViewModel.FLASH_SECONDS / 2)
			expect(mid > 0 and mid < 1).to.equal(true)
			expect(SkillCheckRingViewModel.flash(SkillCheckRingViewModel.FLASH_SECONDS)).to.equal(0)
			expect(SkillCheckRingViewModel.flash(99)).to.equal(0)
		end)

		it("is nothing before it starts", function()
			expect(SkillCheckRingViewModel.flash(-1)).to.equal(0)
		end)
	end)

	describe("shown", function()
		it("shows the ring until a moment after it arrives", function()
			expect(SkillCheckRingViewModel.shown(9, 10)).to.equal(true)
			expect(SkillCheckRingViewModel.shown(10 + SkillCheckRingViewModel.LINGER, 10)).to.equal(true)
			expect(SkillCheckRingViewModel.shown(10 + SkillCheckRingViewModel.LINGER + 0.01, 10)).to.equal(false)
		end)
	end)

	describe("hint", function()
		it("shows the words for the first rings only", function()
			expect(SkillCheckRingViewModel.hint(0, 2)).to.equal(false)
			expect(SkillCheckRingViewModel.hint(1, 2)).to.equal(true)
			expect(SkillCheckRingViewModel.hint(2, 2)).to.equal(true)
			expect(SkillCheckRingViewModel.hint(3, 2)).to.equal(false)
		end)
	end)
end
