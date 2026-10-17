local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
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
end
