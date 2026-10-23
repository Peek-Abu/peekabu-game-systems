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
			-- 44 office pieces (the dust bag went with the Gloom and Gleam economy, the desk calendar left the art
			-- kit), the supply cabinet (a secure hiding spot) and the five small pocketable valuables (the hotbar
			-- inventory), plus 19 keys for the generated Odd Hours B1 kit (doorLeafGlass, three floor variants,
			-- and fifteen furniture pieces including stairwellSign).
			expect(count).to.equal(69)
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
