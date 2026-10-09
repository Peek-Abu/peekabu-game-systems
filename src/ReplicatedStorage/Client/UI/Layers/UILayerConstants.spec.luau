--!nocheck
--[=[
	Unit tests for UILayerConstants — the UI layer ladder.

	The ladder exists because the census found the old game left DisplayOrder at 0 on nearly every
	screen, so layering emerged from Explorer sibling order and needed startup fixup code. These
	assertions pin the ladder as intentional, ordered data.
]=]

local UILayerConstants = require(script.Parent.UILayerConstants)

return function()
	describe("LAYERS ladder", function()
		it("is a non-empty ordered list", function()
			expect(type(UILayerConstants.LAYERS)).to.equal("table")
			expect(#UILayerConstants.LAYERS > 0).to.equal(true)
		end)

		it("is strictly ascending by displayOrder", function()
			local previous = -math.huge
			for _, layer in UILayerConstants.LAYERS do
				expect(layer.displayOrder > previous).to.equal(true)
				previous = layer.displayOrder
			end
		end)

		it("has distinct names and distinct display orders", function()
			local seenName, seenOrder = {}, {}
			for _, layer in UILayerConstants.LAYERS do
				expect(seenName[layer.name]).never.to.be.ok()
				expect(seenOrder[layer.displayOrder]).never.to.be.ok()
				seenName[layer.name] = true
				seenOrder[layer.displayOrder] = true
			end
		end)

		it("puts Hud lowest and Debug highest", function()
			local first = UILayerConstants.LAYERS[1]
			local last = UILayerConstants.LAYERS[#UILayerConstants.LAYERS]
			expect(first.name).to.equal("Hud")
			expect(last.name).to.equal("Debug")
		end)

		it("is frozen (the ladder is not mutated at runtime)", function()
			expect(table.isfrozen(UILayerConstants.LAYERS)).to.equal(true)
			expect(function()
				UILayerConstants.LAYERS[1].displayOrder = 999
			end).to.throw()
		end)
	end)

	describe("orderOf", function()
		it("returns the display order for a known layer", function()
			expect(UILayerConstants.orderOf("Hud")).to.equal(10)
			expect(UILayerConstants.orderOf("Debug")).to.equal(1000)
		end)

		it("errors on an unknown layer name", function()
			expect(function()
				UILayerConstants.orderOf("Nope")
			end).to.throw()
		end)
	end)

	describe("isLayer", function()
		it("is true for declared layers and false otherwise", function()
			expect(UILayerConstants.isLayer("Panel")).to.equal(true)
			expect(UILayerConstants.isLayer("Nope")).to.equal(false)
		end)
	end)
end
