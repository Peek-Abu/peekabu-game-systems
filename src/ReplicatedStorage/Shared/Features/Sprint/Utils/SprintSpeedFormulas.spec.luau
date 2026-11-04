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

	it("scales the sprint by the Speed stat's effect, under the load's slow", function()
		expect(SprintSpeedFormulas.speed(0, 1.06)).to.be.near(24.38, 1e-6)
		expect(SprintSpeedFormulas.speed(nil, 1)).to.equal(23)
		local WEIGHT = CargoConstants.WEIGHT
		expect(SprintSpeedFormulas.speed(WEIGHT.bulky, 1.06)).to.be.near(11.5 * 1.06, 1e-6)
	end)

	it("reads a speed scale, 1 for anything that is not a positive number", function()
		expect(SprintSpeedFormulas.scaleFrom(nil)).to.equal(1)
		expect(SprintSpeedFormulas.scaleFrom("fast")).to.equal(1)
		expect(SprintSpeedFormulas.scaleFrom(-2)).to.equal(1)
		expect(SprintSpeedFormulas.scaleFrom(0)).to.equal(1)
		expect(SprintSpeedFormulas.scaleFrom(1.25)).to.equal(1.25)
	end)

	it("rescales a walk from one scale to another and back exactly", function()
		expect(SprintSpeedFormulas.rescale(20, 1.25, 1)).to.be.near(16, 1e-9)
		expect(SprintSpeedFormulas.rescale(16, 1, 1.25)).to.be.near(20, 1e-9)
		local there = SprintSpeedFormulas.rescale(13.6, 1, 1.25)
		expect(SprintSpeedFormulas.rescale(there, 1.25, 1)).to.be.near(13.6, 1e-9)
	end)
end
