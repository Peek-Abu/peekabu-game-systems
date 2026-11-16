local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local VfxFormulas = require(ReplicatedStorage.Shared.Features.Vfx.Utils.VfxFormulas)
local CargoVfxConstants = require(script.Parent.CargoVfxConstants)

return function()
	it("every preset passes the burst registry's budget", function()
		for id, preset in CargoVfxConstants.PRESETS do
			local specId = `spec-{id}`
			if not VfxBurstRegistry.has(specId) then
				VfxBurstRegistry.register(specId, preset)
			end
			expect(VfxBurstRegistry.has(specId)).to.equal(true)
		end
	end)

	it("the jackpot is over in about a second", function()
		expect(VfxBurstRegistry.tail(CargoVfxConstants.PRESETS.cargoJackpot) <= 1.2).to.equal(true)
	end)

	it("has a reveal amount for every value tier", function()
		for _, tier in { "low", "mid", "high", "jackpot" } do
			expect(CargoVfxConstants.REVEAL_AMOUNT[tier] > 0).to.equal(true)
		end
	end)

	it("draws no teal: the bank refine turns Gloom lilac, then gold (any teal hue, VfxFormulas.teal)", function()
		for id, preset in CargoVfxConstants.PRESETS do
			for _, layer in preset.layers do
				for _, key in layer.color.Keypoints do
					expect(`{id} {VfxFormulas.teal(key.Value)}`).to.equal(`{id} false`)
				end
			end
		end
	end)

	it(
		"reveals with one gold shaft out of the pile, little else (owner round 2 pick: the shaft, less VFX slop)",
		function()
			local layers = CargoVfxConstants.PRESETS.cargoReveal.layers
			expect(#layers <= 3).to.equal(true)
			local shafts, particles = 0, 0
			for _, layer in layers do
				particles += layer.count or 0
				if layer.orientation == Enum.ParticleOrientation.VelocityParallel then
					shafts += 1
					expect(layer.count).to.equal(1)
					-- It rises (the burst emits up) and thins away to nothing.
					expect(layer.speed.Min > 0).to.equal(true)
					local last = layer.size.Keypoints[#layer.size.Keypoints]
					expect(last.Value).to.equal(0)
				end
			end
			expect(shafts).to.equal(1)
			expect(particles <= 10).to.equal(true)
		end
	)
end
