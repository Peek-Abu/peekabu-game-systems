local FootstepGaitFormulas = require(script.Parent.FootstepGaitFormulas)

local SET = {
	walkSpeed = 10,
	runSpeed = 20,
	gaits = {
		walk = { volume = 1, pitch = 1 },
		sprint = { volume = 1.6, pitch = 1.1 },
		crouch = { volume = 0.4, pitch = 0.9 },
		hidden = { volume = 0, pitch = 1 },
	},
}

return function()
	describe("gaitFor", function()
		it("hidden beats crouching beats sprinting beats walking", function()
			expect(FootstepGaitFormulas.gaitFor({ hidden = true, crouching = true, sprinting = true })).to.equal(
				"hidden"
			)
			expect(FootstepGaitFormulas.gaitFor({ hidden = false, crouching = true, sprinting = true })).to.equal(
				"crouch"
			)
			expect(FootstepGaitFormulas.gaitFor({ hidden = false, crouching = false, sprinting = true })).to.equal(
				"sprint"
			)
			expect(FootstepGaitFormulas.gaitFor({ hidden = false, crouching = false, sprinting = false })).to.equal(
				"walk"
			)
		end)
	end)

	describe("scale", function()
		it("is the walk at walking speed and below", function()
			local scale = FootstepGaitFormulas.scale(SET, "walk", 10)
			expect(scale.volume).to.equal(1)
			expect(scale.pitch).to.equal(1)
			expect(FootstepGaitFormulas.scale(SET, "walk", 3).volume).to.equal(1)
		end)

		it("rises with speed toward the sprint (an NPC's chase run has no sprint flag)", function()
			local between = FootstepGaitFormulas.scale(SET, "walk", 15)
			expect(between.volume).to.be.near(1.3, 1e-6)
			expect(between.pitch).to.be.near(1.05, 1e-6)
			expect(FootstepGaitFormulas.scale(SET, "walk", 40).volume).to.be.near(1.6, 1e-6)
		end)

		it("is the full sprint whenever the sprint flag is up", function()
			local scale = FootstepGaitFormulas.scale(SET, "sprint", 12)
			expect(scale.volume).to.be.near(1.6, 1e-6)
			expect(scale.pitch).to.be.near(1.1, 1e-6)
		end)

		it("is the crouch's or hidden's own, whatever the speed", function()
			expect(FootstepGaitFormulas.scale(SET, "crouch", 18).volume).to.equal(0.4)
			expect(FootstepGaitFormulas.scale(SET, "hidden", 18).volume).to.equal(0)
		end)
	end)
end
