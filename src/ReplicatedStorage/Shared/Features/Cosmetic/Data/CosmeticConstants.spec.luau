local CosmeticConstants = require(script.Parent.CosmeticConstants)

return function()
	it("names the slice, the default employee and the slot counts", function()
		expect(CosmeticConstants.SLICE).to.equal("loadout")
		expect(CosmeticConstants.DEFAULT_EMPLOYEE).to.equal("Pippa")
		expect(CosmeticConstants.WHEEL_SLOTS).to.equal(4)
		expect(CosmeticConstants.STICKER_SLOTS).to.equal(4)
		expect(CosmeticConstants.MAX_STYLES >= 3).to.equal(true)
	end)

	it("builds a fresh default loadout each call: Pippa, not picked, 4 empty sticker slots", function()
		local a = CosmeticConstants.defaultLoadout()
		local b = CosmeticConstants.defaultLoadout()
		expect(a).never.to.equal(b)
		expect(a.current).to.equal("Pippa")
		expect(a.picked).to.equal(false)
		expect(next(a.looks)).never.to.be.ok()
		expect(#a.stickers).to.equal(4)
		for _, sticker in a.stickers do
			expect(sticker).to.equal("")
		end
		expect(next(a.seen)).never.to.be.ok()
	end)
end
