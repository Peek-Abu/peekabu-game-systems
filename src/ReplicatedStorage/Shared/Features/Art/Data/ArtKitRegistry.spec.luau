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
			expect(count > 0).to.equal(true)
			expect(Registry.contains("furniture", "supplyCabinet")).to.equal(true)
			expect(Registry.contains("furniture", "serverRack")).to.equal(true)
			expect(Registry.contains("building", "doorLeafGlass")).to.equal(true)
			expect(Registry.contains("furniture", "stairwellSign")).to.equal(true)
			expect(Registry.contains("building", "stairwellSign")).to.equal(false)
			expect(Registry.kits["odd-hours-b1"] ~= nil).to.equal(true)
			expect(Registry.contains("cargo", "dustBag")).to.equal(false)
			expect(Registry.contains("cargo", "deskPhone")).to.equal(false)
			expect(Registry.contains("cargo", "keyring")).to.equal(true)
			expect(Registry.contains("cargo", "printer")).to.equal(false)
			expect(Registry.contains("props", "deskCalendar")).to.equal(false)
			expect(Registry.contains("equipment", "vacuum")).to.equal(false)
		end)
	end)
end
