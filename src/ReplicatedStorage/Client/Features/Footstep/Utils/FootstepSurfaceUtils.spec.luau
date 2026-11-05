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

	describe("surfaceFor outside", function()
		it("maps the yard's ground materials to the outdoor surfaces", function()
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Grass, nil)).to.equal("grass")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.LeafyGrass, nil)).to.equal("grass")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Ground, nil)).to.equal("grass")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Pebble, nil)).to.equal("gravel")
		end)

		it("is asphalt for Asphalt and Pavement outside, concrete in the building", function()
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Asphalt, nil, "Outside")).to.equal("asphalt")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Pavement, nil, "Outside")).to.equal("asphalt")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Asphalt, nil, "Building")).to.equal("concrete")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Pavement, nil, "Building")).to.equal("concrete")
			-- Indoor materials stay themselves outside.
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Concrete, nil, "Outside")).to.equal("concrete")
		end)

		it(
			"is asphalt for Asphalt and Pavement with no place cut (before a shift: the yard has no boxes yet)",
			function()
				expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Asphalt, nil)).to.equal("asphalt")
				expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Pavement, nil, nil)).to.equal("asphalt")
			end
		)

		it("takes the outdoor names from the FootstepSurface attribute (the yard's puddle discs)", function()
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Glass, "puddle")).to.equal("puddle")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Plastic, "gravel")).to.equal("gravel")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Plastic, "grass")).to.equal("grass")
			expect(FootstepSurfaceUtils.surfaceFor(Enum.Material.Plastic, "asphalt")).to.equal("asphalt")
		end)
	end)

	describe("layerFor", function()
		it("is the shared layer of an outdoor surface", function()
			expect(FootstepSurfaceUtils.layerFor("asphalt")).to.equal("asphalt")
			expect(FootstepSurfaceUtils.layerFor("grass")).to.equal("grass")
			expect(FootstepSurfaceUtils.layerFor("gravel")).to.equal("gravel")
			expect(FootstepSurfaceUtils.layerFor("puddle")).to.equal("puddle")
		end)

		it("is none indoors: nothing changes inside", function()
			for _, surface in { "default", "carpet", "tile", "wood", "concrete" } do
				expect(FootstepSurfaceUtils.layerFor(surface)).to.equal(nil)
			end
		end)
	end)

	describe("layerPool", function()
		local layers = { asphalt = { "a1" }, grass = { "g1", "g2" }, gravel = {}, puddle = { "p1" } }

		it("is the layer's own list", function()
			expect(FootstepSurfaceUtils.layerPool(layers, "grass")[2]).to.equal("g2")
			expect(FootstepSurfaceUtils.layerPool(layers, "puddle")[1]).to.equal("p1")
			expect(#FootstepSurfaceUtils.layerPool(layers, "gravel")).to.equal(0)
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

		it("keeps each character's own step outside (the default pool)", function()
			for _, surface in { "asphalt", "grass", "gravel", "puddle" } do
				expect(FootstepSurfaceUtils.poolFor(pools, surface)[1]).to.equal("a")
			end
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
