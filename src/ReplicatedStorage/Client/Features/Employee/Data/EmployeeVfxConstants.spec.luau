local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local EmployeeVfxConstants = require(script.Parent.EmployeeVfxConstants)

return function()
	it("every preset passes the burst registry's budget", function()
		for id, preset in EmployeeVfxConstants.PRESETS do
			local specId = `spec-{id}`
			if not VfxBurstRegistry.has(specId) then
				VfxBurstRegistry.register(specId, preset)
			end
			expect(VfxBurstRegistry.has(specId)).to.equal(true)
		end
	end)

	it("the swap puff is goo and gold: no light, nothing red", function()
		local goo = EmployeeVfxConstants.PRESETS.employeeSwapGoo
		expect(goo).to.be.ok()
		expect(goo.light).to.equal(nil)
		for _, layer in goo.layers do
			for _, point in layer.color.Keypoints do
				local c = point.Value
				expect(c.R - math.max(c.G, c.B) < 0.25).to.equal(true)
			end
		end
	end)

	it("settles briefly before playing", function()
		expect(EmployeeVfxConstants.SWAP_SETTLE >= 0).to.equal(true)
		expect(EmployeeVfxConstants.SWAP_SETTLE < 1).to.equal(true)
	end)
end
