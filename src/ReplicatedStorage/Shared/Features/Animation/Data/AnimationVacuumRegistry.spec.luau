local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Registry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationVacuumRegistry)
return function()
	it("never invents production IDs before the named upload is approved", function()
		expect(next(Registry)).to.equal(nil)
	end)
end
