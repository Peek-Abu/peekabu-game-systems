--[=[
	Unit tests for AnimationTypes — the shared type vocabulary of the animation registry. The module
	is almost entirely types (erased at runtime), so the observable surface is the interruption-class
	list and its guard.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationTypes = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationTypes)

return function()
	describe("INTERRUPTION_CLASSES", function()
		it("lists exactly the three declared classes", function()
			local classes = AnimationTypes.INTERRUPTION_CLASSES
			expect(#classes).to.equal(3)
			local seen = {}
			for _, class in classes do
				seen[class] = true
			end
			expect(seen.attack).to.equal(true)
			expect(seen.protected).to.equal(true)
			expect(seen.ambient).to.equal(true)
		end)

		it("is frozen — the class list is data, not a mutable table", function()
			expect(table.isfrozen(AnimationTypes.INTERRUPTION_CLASSES)).to.equal(true)
		end)
	end)

	describe("ANIMATION_LAYERS", function()
		it("lists full, upper and overlay in wire order", function()
			local layers = AnimationTypes.ANIMATION_LAYERS
			expect(#layers).to.equal(3)
			expect(layers[1]).to.equal("full")
			expect(layers[2]).to.equal("upper")
			expect(layers[3]).to.equal("overlay")
		end)

		it("is frozen — the wire order is data, not a mutable table", function()
			expect(table.isfrozen(AnimationTypes.ANIMATION_LAYERS)).to.equal(true)
		end)
	end)

	describe("layer lookups", function()
		it("isAnimationLayer accepts each layer and rejects anything else", function()
			for _, layer in AnimationTypes.ANIMATION_LAYERS do
				expect(AnimationTypes.isAnimationLayer(layer)).to.equal(true)
			end
			expect(AnimationTypes.isAnimationLayer("legs")).to.equal(false)
			expect(AnimationTypes.isAnimationLayer(nil)).to.equal(false)
			expect(AnimationTypes.isAnimationLayer(1)).to.equal(false)
		end)

		it("layerIndex and layerAt round-trip, and refuse what is no layer", function()
			for index, layer in AnimationTypes.ANIMATION_LAYERS do
				expect(AnimationTypes.layerIndex(layer)).to.equal(index)
				expect(AnimationTypes.layerAt(index)).to.equal(layer)
			end
			expect(AnimationTypes.layerIndex("legs")).to.equal(nil)
			expect(AnimationTypes.layerAt(0)).to.equal(nil)
			expect(AnimationTypes.layerAt(4)).to.equal(nil)
		end)

		it("layerNamed narrows a layer name and refuses anything else", function()
			expect(AnimationTypes.layerNamed("upper")).to.equal("upper")
			expect(AnimationTypes.layerNamed("testleap")).to.equal(nil)
		end)
	end)

	describe("wire limits", function()
		it("fits wire ids in a uint16 and variant indexes in a uint8", function()
			expect(AnimationTypes.MAX_WIRE_ID).to.equal(65535)
			expect(AnimationTypes.MAX_VARIANTS).to.equal(255)
		end)
	end)

	describe("isInterruptionClass", function()
		it("accepts each declared class", function()
			expect(AnimationTypes.isInterruptionClass("attack")).to.equal(true)
			expect(AnimationTypes.isInterruptionClass("protected")).to.equal(true)
			expect(AnimationTypes.isInterruptionClass("ambient")).to.equal(true)
		end)

		it("rejects unknown strings and non-strings", function()
			expect(AnimationTypes.isInterruptionClass("attacks")).to.equal(false)
			expect(AnimationTypes.isInterruptionClass("")).to.equal(false)
			expect(AnimationTypes.isInterruptionClass(nil)).to.equal(false)
			expect(AnimationTypes.isInterruptionClass(42)).to.equal(false)
		end)
	end)

	describe("isCanonicalAssetId", function()
		it("accepts the one canonical form", function()
			expect(AnimationTypes.isCanonicalAssetId("rbxassetid://11526063910")).to.equal(true)
		end)

		it("rejects the legacy URL form the old game mixed in", function()
			expect(AnimationTypes.isCanonicalAssetId("http://www.roblox.com/asset/?id=11526063910")).to.equal(false)
		end)

		it("rejects a bare number, empty id, trailing garbage, and non-strings", function()
			expect(AnimationTypes.isCanonicalAssetId("11526063910")).to.equal(false)
			expect(AnimationTypes.isCanonicalAssetId("rbxassetid://")).to.equal(false)
			expect(AnimationTypes.isCanonicalAssetId("rbxassetid://123abc")).to.equal(false)
			expect(AnimationTypes.isCanonicalAssetId(nil)).to.equal(false)
		end)
	end)
end
