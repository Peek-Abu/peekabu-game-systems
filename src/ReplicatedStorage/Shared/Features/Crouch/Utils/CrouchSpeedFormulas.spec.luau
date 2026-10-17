local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrouchSpeedFormulas = require(script.Parent.CrouchSpeedFormulas)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CarryFormulas = require(ReplicatedStorage.Shared.Features.Carry.Utils.CarryFormulas)
local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)

return function()
	it("creeps at CROUCH_SPEED empty-handed: 55-60 % of the walk (16)", function()
		expect(CrouchSpeedFormulas.speed(nil)).to.equal(CrouchConstants.CROUCH_SPEED)
		expect(CrouchSpeedFormulas.speed(0)).to.equal(CrouchConstants.CROUCH_SPEED)
		local fraction = CrouchConstants.CROUCH_SPEED / 16
		expect(fraction >= 0.55 and fraction <= 0.6).to.equal(true)
	end)

	it("slows the crouch by the carry's own walk factor (the small items a crouch allows)", function()
		for _, weight in CargoConstants.WEIGHT do
			local walk = CarryFormulas.carrierSpeed(16, weight)
			expect(CrouchSpeedFormulas.speed(weight)).to.be.near(CrouchConstants.CROUCH_SPEED * walk / 16, 1e-9)
		end
	end)

	it("is always slower than the walk it replaces", function()
		for _, weight in CargoConstants.WEIGHT do
			expect(CrouchSpeedFormulas.speed(weight) < CarryFormulas.carrierSpeed(16, weight)).to.equal(true)
		end
	end)
end
