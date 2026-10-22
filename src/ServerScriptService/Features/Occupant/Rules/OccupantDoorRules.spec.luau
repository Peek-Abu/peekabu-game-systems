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
end
