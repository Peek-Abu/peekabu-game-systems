local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Registry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)
local Cargo = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
return function()
	it("defines a real grasp style for every current cargo without a fabricated animation ID", function()
		for _, id in Cargo.ids() do
			local style = Registry.get(id)
			expect(style).to.be.ok()
			expect(style == "handle" or style == "small" or style == "twoHand").to.equal(true)
		end
		expect(Registry.get("unknown")).to.equal("twoHand")
	end)
end
