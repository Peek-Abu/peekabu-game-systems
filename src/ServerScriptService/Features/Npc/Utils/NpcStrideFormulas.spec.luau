local ServerScriptService = game:GetService("ServerScriptService")

local NpcConstants = require(ServerScriptService.Features.Npc.Data.NpcConstants)
local NpcStrideFormulas = require(script.Parent.NpcStrideFormulas)

return function()
	describe("rate", function()
		it("plays the stride at 1x at the speed its feet plant at", function()
			expect(NpcStrideFormulas.rate(10, 10)).to.be.near(1, 1e-9)
		end)

		it("follows the NPC's speed, so the feet stay planted when it walks faster or slower", function()
			expect(NpcStrideFormulas.rate(14, 10)).to.be.near(1.4, 1e-9)
			expect(NpcStrideFormulas.rate(16, 20)).to.be.near(0.8, 1e-9)
		end)

		it("is clamped, so a stall or a shove never freezes or blurs the clip", function()
			expect(NpcStrideFormulas.rate(0.1, 10)).to.equal(NpcConstants.STRIDE_MIN_RATE)
			expect(NpcStrideFormulas.rate(500, 10)).to.equal(NpcConstants.STRIDE_MAX_RATE)
		end)

		it("plays at 1x when the clip names no planted speed", function()
			expect(NpcStrideFormulas.rate(14, nil)).to.equal(1)
			expect(NpcStrideFormulas.rate(14, 0)).to.equal(1)
		end)
	end)
end
