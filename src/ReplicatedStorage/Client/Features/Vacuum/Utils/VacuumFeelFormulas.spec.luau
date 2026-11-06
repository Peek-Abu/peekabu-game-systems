local VacuumFeelFormulas = require(script.Parent.VacuumFeelFormulas)

return function()
	describe("lean", function()
		it("leans a pile toward the nozzle, more as it nears done", function()
			local start = VacuumFeelFormulas.lean(2, 0)
			local late = VacuumFeelFormulas.lean(2, 1)
			expect(start > 0 and late > start).to.equal(true)
			expect(late <= VacuumFeelFormulas.MAX_LEAN).to.equal(true)
		end)

		it("leans less when the nozzle is far, never backwards", function()
			expect(VacuumFeelFormulas.lean(12, 1) < VacuumFeelFormulas.lean(2, 1)).to.equal(true)
			expect(VacuumFeelFormulas.lean(100, 1) >= 0).to.equal(true)
		end)
	end)

	describe("stretch", function()
		it("stretches a pile up toward the nozzle and thins it, keeping about its volume", function()
			local up, across = VacuumFeelFormulas.stretch(1, 0)
			expect(up > 1 and across < 1).to.equal(true)
			expect(math.abs(up * across * across - 1) < 0.01).to.equal(true)
		end)

		it("is the plain pile with no pull, and a tug stretches it further", function()
			local up, across = VacuumFeelFormulas.stretch(0, 0)
			expect(up).to.equal(1)
			expect(across).to.equal(1)
			expect(VacuumFeelFormulas.stretch(0.5, 1) > VacuumFeelFormulas.stretch(0.5, 0)).to.equal(true)
		end)
	end)

	describe("wobble", function()
		it("is small at the start of a pile and grows as it nears done", function()
			local function peak(progress)
				local most = 0
				for step = 0, 200 do
					most = math.max(most, math.abs(VacuumFeelFormulas.wobble(step / 60, 7, progress)))
				end
				return most
			end
			expect(peak(1) > peak(0) * 2).to.equal(true)
			expect(peak(1) <= VacuumFeelFormulas.MAX_WOBBLE + 1e-9).to.equal(true)
		end)
	end)

	describe("camera", function()
		it("widens the view a little while sucking, more near done, none when not", function()
			expect(VacuumFeelFormulas.fov(false, 1)).to.equal(0)
			local start = VacuumFeelFormulas.fov(true, 0)
			local late = VacuumFeelFormulas.fov(true, 1)
			expect(start > 0 and late > start).to.equal(true)
			expect(late <= 6).to.equal(true)
		end)

		it("adds strain only once a pile is well under way, growing to its most", function()
			expect(VacuumFeelFormulas.strain(0.1)).to.equal(0)
			expect(VacuumFeelFormulas.strain(1) > VacuumFeelFormulas.strain(0.6)).to.equal(true)
			expect(VacuumFeelFormulas.strain(1) <= VacuumFeelFormulas.MAX_STRAIN).to.equal(true)
		end)

		it("punches a bigger pop harder, within bounds", function()
			expect(VacuumFeelFormulas.popTrauma(8) > VacuumFeelFormulas.popTrauma(3)).to.equal(true)
			expect(VacuumFeelFormulas.popTrauma(100) <= 0.45).to.equal(true)
			expect(VacuumFeelFormulas.popTrauma(0) > 0).to.equal(true)
		end)
	end)
end
