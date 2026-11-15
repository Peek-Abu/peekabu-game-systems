local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local VfxConstants = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxConstants)
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

	it("draws no teal: Gloom fades to the UI's lilac rim, never VfxConstants' teal gloomEdge (P1 v2)", function()
		local teal = VfxConstants.PALETTE.gloomEdge
		for id, preset in VacuumVfxConstants.PRESETS do
			for _, layer in preset.layers do
				for _, key in layer.color.Keypoints do
					local c = key.Value
					local same = math.abs(c.R - teal.R) < 1e-3
						and math.abs(c.G - teal.G) < 1e-3
						and math.abs(c.B - teal.B) < 1e-3
					expect(`{id} {same}`).to.equal(`{id} false`)
				end
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
