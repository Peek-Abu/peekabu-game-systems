local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local ShiftPlaceRules = require(script.Parent.ShiftPlaceRules)

return function()
	describe("isStrandedServer", function()
		it("is a live public server of the shift place", function()
			expect(ShiftPlaceRules.isStrandedServer("live", DepotConstants.ROLE_SHIFT, false)).to.equal(true)
		end)

		it("is never a reserved party server", function()
			expect(ShiftPlaceRules.isStrandedServer("live", DepotConstants.ROLE_SHIFT, true)).to.equal(false)
		end)

		it("is never the hub", function()
			expect(ShiftPlaceRules.isStrandedServer("live", DepotConstants.ROLE_DEPOT, false)).to.equal(false)
		end)

		it("is never Studio or an unknown place (local mode)", function()
			expect(ShiftPlaceRules.isStrandedServer("local", DepotConstants.ROLE_SHIFT, false)).to.equal(false)
			expect(ShiftPlaceRules.isStrandedServer("local", nil, false)).to.equal(false)
		end)

		it("is never a live server with no role", function()
			expect(ShiftPlaceRules.isStrandedServer("live", nil, false)).to.equal(false)
		end)
	end)
end
