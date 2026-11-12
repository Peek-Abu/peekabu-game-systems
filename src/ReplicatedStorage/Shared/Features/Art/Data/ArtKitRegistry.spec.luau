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
		it("holds the School's own furniture keys", function()
			for _, key in { "studentDesk", "chalkboard", "lunchTable", "servingCounter", "trophyCase", "bleachers" } do
				expect(Registry.contains("furniture", key)).to.equal(true)
			end
		end)
		it("chains a kit through its fallbacks to the default kit, each once", function()
			local school = Registry.chain("school-maple-hill")
			expect(school[1]).to.equal("school-maple-hill")
			expect(school[2]).to.equal("odd-hours-b1")
			expect(school[3]).to.equal(Registry.DEFAULT_KIT)
			expect(#school).to.equal(3)
			local office = Registry.chain("odd-hours-b1")
			expect(office[1]).to.equal("odd-hours-b1")
			expect(office[2]).to.equal(Registry.DEFAULT_KIT)
			expect(#office).to.equal(2)
			local default = Registry.chain(Registry.DEFAULT_KIT)
			expect(#default).to.equal(1)
			-- An unknown kit (a place-only kit) still ends at the default kit.
			local unknown = Registry.chain("place-only")
			expect(unknown[1]).to.equal("place-only")
			expect(unknown[2]).to.equal(Registry.DEFAULT_KIT)
		end)
	end)
end
