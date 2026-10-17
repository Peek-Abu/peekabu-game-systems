local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local VacuumVfxConstants = require(script.Parent.VacuumVfxConstants)

return function()
	it("every preset passes the burst registry's budget", function()
		for id, preset in VacuumVfxConstants.PRESETS do
			local specId = `spec-{id}`
			if not VfxBurstRegistry.has(specId) then
				VfxBurstRegistry.register(specId, preset)
			end
			expect(VfxBurstRegistry.has(specId)).to.equal(true)
		end
	end)

	it("the suction streams only stream and the one-shots only burst", function()
		for _, id in { "vacuumSuction", "vacuumGrimeSuction" } do
			for _, layer in VacuumVfxConstants.PRESETS[id].layers do
				expect(layer.rate ~= nil and layer.count == nil).to.equal(true)
			end
		end
		for _, id in { "vacuumPuff", "vacuumPop", "vacuumShine", "vacuumShineSparkle" } do
			for _, layer in VacuumVfxConstants.PRESETS[id].layers do
				expect(layer.count ~= nil and layer.rate == nil).to.equal(true)
			end
		end
	end)

	it("keeps the pop readable but not noisy (24 particles at most)", function()
		local total = 0
		for _, layer in VacuumVfxConstants.PRESETS.vacuumPop.layers do
			total += layer.count
		end
		expect(total <= 24).to.equal(true)
	end)
end
