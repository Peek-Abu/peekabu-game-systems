local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local AbilityVfxConstants = require(script.Parent.AbilityVfxConstants)

return function()
	it("every preset passes the burst registry's budget", function()
		for id, preset in AbilityVfxConstants.PRESETS do
			local specId = `spec-{id}`
			if not VfxBurstRegistry.has(specId) then
				VfxBurstRegistry.register(specId, preset)
			end
			expect(VfxBurstRegistry.has(specId)).to.equal(true)
		end
	end)

	it("has the rally and the plant puff, kid-safe: no light, nothing red", function()
		expect(AbilityVfxConstants.PRESETS.abilityLetsGo).to.be.ok()
		expect(AbilityVfxConstants.PRESETS.abilityPlantPuff).to.be.ok()
		for _, preset in AbilityVfxConstants.PRESETS do
			expect(preset.light).to.equal(nil)
			for _, layer in preset.layers do
				for _, point in layer.color.Keypoints do
					local c = point.Value
					expect(c.R - math.max(c.G, c.B) < 0.25).to.equal(true)
				end
			end
		end
	end)

	it("draws no speed trail on boosted runners (owner, 2026-11-03)", function()
		for key in AbilityVfxConstants do
			expect(string.find(key, "^TRAIL_")).to.equal(nil)
		end
	end)
end
