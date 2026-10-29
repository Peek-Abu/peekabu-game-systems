local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotTruckPopFormulas = require(script.Parent.DepotTruckPopFormulas)
local DepotTruckPopConstants = require(ReplicatedStorage.Client.Features.Depot.Data.DepotTruckPopConstants)

local POP = DepotTruckPopConstants.POP_SECONDS
local GHOST = DepotTruckPopConstants.GHOST_TRANSPARENCY

return function()
	describe("scale", function()
		it("starts small, overshoots, and settles at exactly 1", function()
			expect(DepotTruckPopFormulas.scale(0)).to.equal(DepotTruckPopConstants.START_SCALE)
			local peak = 0
			for step = 0, 20 do
				peak = math.max(peak, DepotTruckPopFormulas.scale(POP * step / 20))
			end
			expect(peak > 1).to.equal(true)
			expect(DepotTruckPopFormulas.scale(POP)).to.equal(1)
		end)

		it("stays at 1 after the pop and at the start before it", function()
			expect(DepotTruckPopFormulas.scale(POP * 3)).to.equal(1)
			expect(DepotTruckPopFormulas.scale(-1)).to.equal(DepotTruckPopConstants.START_SCALE)
		end)
	end)

	describe("transparency", function()
		it("fades from the ghost to solid while the truck pops in", function()
			expect(DepotTruckPopFormulas.transparency(0, true)).to.be.near(GHOST)
			expect(DepotTruckPopFormulas.transparency(POP, true)).to.equal(0)
			local mid = DepotTruckPopFormulas.transparency(POP / 2, true)
			expect(mid > 0 and mid < GHOST).to.equal(true)
		end)

		it("fades back to the ghost when the truck leaves", function()
			local leave = DepotTruckPopConstants.LEAVE_SECONDS
			expect(DepotTruckPopFormulas.transparency(0, false)).to.equal(0)
			expect(DepotTruckPopFormulas.transparency(leave, false)).to.be.near(GHOST)
			expect(DepotTruckPopFormulas.transparency(leave * 2, false)).to.be.near(GHOST)
		end)
	end)
end
