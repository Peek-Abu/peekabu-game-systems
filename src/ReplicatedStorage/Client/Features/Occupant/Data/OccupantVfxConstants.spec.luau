local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local OccupantVfxConstants = require(script.Parent.OccupantVfxConstants)

return function()
	it("every preset passes the burst registry's budget", function()
		for id, preset in OccupantVfxConstants.PRESETS do
			local specId = `spec-{id}`
			if not VfxBurstRegistry.has(specId) then
				VfxBurstRegistry.register(specId, preset)
			end
			expect(VfxBurstRegistry.has(specId)).to.equal(true)
		end
	end)

	it("the catch stays kid-safe: no light, nothing red", function()
		local crack = OccupantVfxConstants.PRESETS.occupantCatchCrack
		expect(crack.light).to.equal(nil)
		for _, layer in crack.layers do
			for _, point in layer.color.Keypoints do
				local c = point.Value
				expect(c.R - math.max(c.G, c.B) < 0.25).to.equal(true)
			end
		end
	end)

	it("waits a positive time for the new character", function()
		expect(OccupantVfxConstants.REHIRE_WAIT > 0).to.equal(true)
	end)
end
