local VacuumLatchRules = require(script.Parent.VacuumLatchRules)

return function()
	describe("press", function()
		it("starts the vacuum when it is off, in either mode", function()
			expect(VacuumLatchRules.press(true, false)).to.equal("begin")
			expect(VacuumLatchRules.press(false, false)).to.equal("begin")
		end)

		it("stops a latched vacuum on the second press", function()
			expect(VacuumLatchRules.press(true, true)).to.equal("end")
		end)

		it("never stops a held vacuum on a press (hold mode)", function()
			expect(VacuumLatchRules.press(false, true)).to.equal("begin")
		end)
	end)

	describe("release", function()
		it("keeps a latched vacuum on when the button is let go", function()
			expect(VacuumLatchRules.release(true)).to.equal(false)
		end)

		it("stops a held vacuum when the button is let go (hold mode)", function()
			expect(VacuumLatchRules.release(false)).to.equal(true)
		end)
	end)

	describe("allows", function()
		it("lets a held vacuum move from pile to pile (hold mode)", function()
			expect(VacuumLatchRules.allows(false, "a", "b")).to.equal(true)
		end)

		it("lets a fresh latch take the first pile it finds", function()
			expect(VacuumLatchRules.allows(true, nil, "a")).to.equal(true)
		end)

		it("keeps a latch on its own pile, never the next one", function()
			expect(VacuumLatchRules.allows(true, "a", "a")).to.equal(true)
			expect(VacuumLatchRules.allows(true, "a", "b")).to.equal(false)
		end)
	end)

	describe("keepWithoutTarget", function()
		it("keeps a held vacuum on with nothing in reach (hold mode)", function()
			expect(VacuumLatchRules.keepWithoutTarget(false, true, 5, 0.3)).to.equal(true)
			expect(VacuumLatchRules.keepWithoutTarget(false, false, 5, 0.3)).to.equal(true)
		end)

		it("stops a latched vacuum once its pile is clean or out of reach", function()
			expect(VacuumLatchRules.keepWithoutTarget(true, true, 0.05, 0.3)).to.equal(false)
			expect(VacuumLatchRules.keepWithoutTarget(true, true, 4, 0.3)).to.equal(false)
		end)

		it("gives a fresh latch a moment to find a pile, then stops", function()
			expect(VacuumLatchRules.keepWithoutTarget(true, false, 0.1, 0.3)).to.equal(true)
			expect(VacuumLatchRules.keepWithoutTarget(true, false, 0.3, 0.3)).to.equal(false)
			expect(VacuumLatchRules.keepWithoutTarget(true, false, 1, 0.3)).to.equal(false)
		end)
	end)
end
