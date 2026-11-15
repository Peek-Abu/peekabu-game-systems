local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local ShiftLeavingRules = require(script.Parent.ShiftLeavingRules)

return function()
	describe("view", function()
		it("sends a trip back to the depot home", function()
			local view = ShiftLeavingRules.view(DepotConstants.ROLE_DEPOT, { contract = "x", truck = 2 })
			expect(view.home).to.equal(true)
			expect(view.client).to.equal(nil)
		end)

		it("names the contract's client, the truck and the map on a trip to a shift", function()
			local office = DepotMapRules.contractsOf("office")
			local view = ShiftLeavingRules.view(
				DepotConstants.ROLE_SHIFT,
				{ contract = office[2].id, truck = 3, map = "office" }
			)
			expect(view.home).to.equal(false)
			expect(view.client).to.equal(office[2].client)
			expect(view.truck).to.equal(3)
			expect(view.map).to.equal("office")
		end)

		it("reads a School run's contract among the School's jobs", function()
			local school = DepotMapRules.contractsOf("school")
			local view = ShiftLeavingRules.view(DepotConstants.ROLE_SHIFT, { contract = school[1].id, map = "school" })
			expect(view.client).to.equal(school[1].client)
			expect(view.map).to.equal("school")
		end)

		it("names the training room on a training trip", function()
			local view = ShiftLeavingRules.view(
				DepotConstants.ROLE_SHIFT,
				{ [TrainingConstants.MODE_KEY] = TrainingConstants.MODE, truck = 1 }
			)
			expect(view.client).to.equal(TrainingConstants.CONTRACT.client)
			expect(view.map).to.equal("office")
		end)

		it("drops a forged truck number and an unknown contract (the first job instead)", function()
			local view = ShiftLeavingRules.view(DepotConstants.ROLE_SHIFT, { contract = "nope", truck = 99 })
			expect(view.truck).to.equal(nil)
			expect(view.client).to.equal(DepotMapRules.contractsOf("office")[1].client)
		end)
	end)
end
