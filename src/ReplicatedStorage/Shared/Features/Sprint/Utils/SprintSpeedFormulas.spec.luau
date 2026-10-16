local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SprintSpeedFormulas = require(script.Parent.SprintSpeedFormulas)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CarryFormulas = require(ReplicatedStorage.Shared.Features.Carry.Utils.CarryFormulas)
local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)

return function()
	it("sprints at SPRINT_SPEED empty-handed", function()
		expect(SprintSpeedFormulas.speed(nil)).to.equal(SprintConstants.SPRINT_SPEED)
		expect(SprintSpeedFormulas.speed(0)).to.equal(23)
	end)

	it("slows the sprint by the carry's own walk factor: 23 x (carried walk / 16)", function()
		for _, weight in CargoConstants.WEIGHT do
			local walk = CarryFormulas.carrierSpeed(16, weight)
			expect(SprintSpeedFormulas.speed(weight)).to.be.near(23 * walk / 16, 1e-9)
		end
	end)

	it("matches the approved figures by size", function()
		local WEIGHT = CargoConstants.WEIGHT
		expect(SprintSpeedFormulas.speed(WEIGHT.light)).to.be.near(21.275, 1e-6)
		expect(SprintSpeedFormulas.speed(WEIGHT.medium)).to.be.near(18.4, 1e-6)
		expect(SprintSpeedFormulas.speed(WEIGHT.heavy)).to.be.near(14.95, 1e-6)
		expect(SprintSpeedFormulas.speed(WEIGHT.bulky)).to.be.near(11.5, 1e-6)
		-- Only a light load still outruns the Manager's chase (20).
		expect(SprintSpeedFormulas.speed(WEIGHT.light) > 20).to.equal(true)
		expect(SprintSpeedFormulas.speed(WEIGHT.medium) < 20).to.equal(true)
	end)
end
