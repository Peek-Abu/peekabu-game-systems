return function()
	local Registry = require(script.Parent.ArtKitRegistry)
	describe("ArtKitRegistry", function()
		it("covers every semantic asset without duplicate family keys", function()
			local count = 0
			for family, keys in Registry.keys do
				local seen = {}
				for _, key in keys do
					expect(seen[key]).to.equal(nil)
					seen[key] = true
					expect(Registry.contains(family, key)).to.equal(true)
					count += 1
				end
			end
			expect(count).to.equal(46)
			expect(Registry.contains("cargo", "printer")).to.equal(false)
			expect(Registry.contains("equipment", "vacuum")).to.equal(false)
		end)
	end)
end
