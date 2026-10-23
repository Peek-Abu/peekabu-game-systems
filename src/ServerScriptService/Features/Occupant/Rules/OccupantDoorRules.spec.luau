local ServerScriptService = game:GetService("ServerScriptService")

local OccupantDoorRules = require(ServerScriptService.Features.Occupant.Rules.OccupantDoorRules)

return function()
	local GO_TO = { kind = "goTo", position = Vector3.new(10, 0, 20), run = false }

	describe("OccupantDoorRules.hold", function()
		it("stops a walk during the door beat", function()
			expect(OccupantDoorRules.hold(GO_TO, 1, 1.4).kind).to.equal("idle")
		end)

		it("lets the walk go once the beat is over", function()
			expect(OccupantDoorRules.hold(GO_TO, 1.5, 1.4)).to.equal(GO_TO)
			expect(OccupantDoorRules.hold(GO_TO, 1.4, 1.4)).to.equal(GO_TO)
		end)

		it("never holds a catch", function()
			local attack = { kind = "attack", target = 7 }
			expect(OccupantDoorRules.hold(attack, 1, 1.4)).to.equal(attack)
		end)

		it("passes idle through", function()
			local idle = { kind = "idle" }
			expect(OccupantDoorRules.hold(idle, 1, 1.4)).to.equal(idle)
		end)
	end)

	describe("OccupantDoorRules.heading", function()
		local here = Vector3.new(0, 3, 0)
		it("is his flattened, unit velocity while he moves", function()
			local heading = OccupantDoorRules.heading(Vector3.new(0, -8, 6), here, Vector3.new(50, 0, 0))
			expect(heading).to.be.ok()
			expect(math.abs(heading.X) < 1e-6 and math.abs(heading.Y) < 1e-6 and math.abs(heading.Z - 1) < 1e-6).to.equal(
				true
			)
		end)
		it("falls back to the direction of his goal when he stands still", function()
			local heading = OccupantDoorRules.heading(Vector3.new(0.1, 0, 0), here, Vector3.new(0, 0, -20))
			expect(heading).to.be.ok()
			expect(math.abs(heading.Z + 1) < 1e-6 and math.abs(heading.Y) < 1e-6).to.equal(true)
		end)
		it("is nil standing still with no goal, or on it", function()
			expect(OccupantDoorRules.heading(Vector3.zero, here, nil)).to.equal(nil)
			expect(OccupantDoorRules.heading(Vector3.zero, here, Vector3.new(0, 9, 0))).to.equal(nil)
		end)
	end)
end
