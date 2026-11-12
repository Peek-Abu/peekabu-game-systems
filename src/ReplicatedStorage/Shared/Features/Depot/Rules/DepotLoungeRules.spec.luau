local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotLoungeRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotLoungeRules)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)

local LOUNGE = DepotSpotConstants.LOUNGE

return function()
	describe("the sleeper", function()
		it("is Cappy (owner 11-11)", function()
			expect(LOUNGE.EMPLOYEE).to.equal("Cappy")
		end)
	end)

	describe("wakes", function()
		it("wakes and waves when a player walks up", function()
			expect(DepotLoungeRules.wakes(LOUNGE.WAKE_RADIUS - 1, false, nil, 100)).to.equal(true)
		end)

		it("dozes on while they stand there, and for players across the room", function()
			expect(DepotLoungeRules.wakes(LOUNGE.WAKE_RADIUS - 1, true, nil, 100)).to.equal(false)
			expect(DepotLoungeRules.wakes(LOUNGE.WAKE_RADIUS + 1, false, nil, 100)).to.equal(false)
		end)

		it("waits a while before waking again", function()
			expect(DepotLoungeRules.wakes(1, false, 100, 100 + LOUNGE.COOLDOWN - 1)).to.equal(false)
			expect(DepotLoungeRules.wakes(1, false, 100, 100 + LOUNGE.COOLDOWN)).to.equal(true)
		end)
	end)
end
