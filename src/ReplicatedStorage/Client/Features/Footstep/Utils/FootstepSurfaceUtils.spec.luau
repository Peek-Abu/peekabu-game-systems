local FootstepSurfaceUtils = require(script.Parent.FootstepSurfaceUtils)

return function()
	describe("surfaceFor", function()
		it("maps the hub's floor materials to their surfaces", function()
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Carpet, nil)).to.equal("carpet")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Fabric, nil)).to.equal("carpet")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.CeramicTiles, nil)).to.equal("tile")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Marble, nil)).to.equal("tile")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.WoodPlanks, nil)).to.equal("wood")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Wood, nil)).to.equal("wood")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Concrete, nil)).to.equal("concrete")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Pavement, nil)).to.equal("concrete")
		end)

		it("is the default for anything else", function()
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Plastic, nil)).to.equal("default")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.SmoothPlastic, nil)).to.equal("default")
		end)

		it("lets a floor's FootstepSurface attribute override its material", function()
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Plastic, "carpet")).to.equal("carpet")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Carpet, "wood")).to.equal("wood")
			-- An unknown name is ignored.
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Carpet, "lava")).to.equal("carpet")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Carpet, 3)).to.equal("carpet")
		end)
	end)

	describe("poolFor", function()
		local pools = { default = { "a", "b" }, carpet = { "c" }, tile = {}, wood = {}, concrete = {} }

		it("is the surface's own pool", function()
			expect(FootstepSurfaceUtils.poolFor(pools, "carpet")[1]).to.equal("c")
		end)

		it("falls back to the default for an empty surface", function()
			expect(#FootstepSurfaceUtils.poolFor(pools, "tile")).to.equal(2)
			expect(#FootstepSurfaceUtils.poolFor(pools, "wood")).to.equal(2)
		end)
	end)

	describe("pick", function()
		it("picks by the roll, never the last one when there is a choice", function()
			expect(FootstepSurfaceUtils.pick(3, 0, nil)).to.equal(1)
			expect(FootstepSurfaceUtils.pick(3, 0.999, nil)).to.equal(3)
			for roll = 0, 0.99, 0.07 do
				expect(FootstepSurfaceUtils.pick(3, roll, 2)).never.to.equal(2)
				local index = FootstepSurfaceUtils.pick(3, roll, 2)
				expect(index >= 1 and index <= 3).to.equal(true)
			end
		end)

		it("repeats a lone variant and has none for an empty pool", function()
			expect(FootstepSurfaceUtils.pick(1, 0.5, 1)).to.equal(1)
			expect(FootstepSurfaceUtils.pick(0, 0.5, nil)).to.equal(nil)
		end)
	end)
end
