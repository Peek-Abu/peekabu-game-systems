local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local DepotTruckPopConstants = require(script.Parent.DepotTruckPopConstants)

return function()
	it("the pop puff passes the burst registry's budget", function()
		local specId = "spec-depotTruckPop"
		if not VfxBurstRegistry.has(specId) then
			VfxBurstRegistry.register(specId, DepotTruckPopConstants.PUFF)
		end
		expect(VfxBurstRegistry.has(specId)).to.equal(true)
	end)

	it("is a quick dust puff: no light, nothing red", function()
		local puff = DepotTruckPopConstants.PUFF
		expect(puff.light).to.equal(nil)
		for _, layer in puff.layers do
			for _, point in layer.color.Keypoints do
				local c = point.Value
				expect(c.R - math.max(c.G, c.B) < 0.25).to.equal(true)
			end
		end
	end)

	it("pops quickly and leaves a faint ghost", function()
		expect(DepotTruckPopConstants.POP_SECONDS > 0 and DepotTruckPopConstants.POP_SECONDS <= 1).to.equal(true)
		expect(DepotTruckPopConstants.LEAVE_SECONDS > 0 and DepotTruckPopConstants.LEAVE_SECONDS <= 1).to.equal(true)
		expect(DepotTruckPopConstants.GHOST_TRANSPARENCY > 0.5).to.equal(true)
		expect(DepotTruckPopConstants.GHOST_TRANSPARENCY < 1).to.equal(true)
		expect(DepotTruckPopConstants.START_SCALE < 1).to.equal(true)
	end)
end
