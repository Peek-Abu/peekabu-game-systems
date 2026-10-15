local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Registry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)
local Cargo = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
return function()
	it("pins no current cargo kind: every hold is chosen by the rules", function()
		for _, id in Cargo.ids() do
			expect(Registry.get(id)).to.equal(nil)
		end
		expect(Registry.get("unknown")).to.equal(nil)
	end)
end
