local AnalyticsRules = require(script.Parent.AnalyticsRules)

return function()
	describe("name", function()
		it("trims whitespace and caps the length", function()
			expect(AnalyticsRules.name("  shop open  ")).to.equal("shop open")
			expect(#AnalyticsRules.name(string.rep("x", 80))).to.equal(AnalyticsRules.MAX_NAME_LENGTH)
		end)

		it("is nil for an empty name", function()
			expect(AnalyticsRules.name("   ")).to.equal(nil)
		end)
	end)

	describe("customFields", function()
		it("maps up to three values onto the engine's custom field keys", function()
			local fields = AnalyticsRules.customFields({ "egg", "night 2" })
			expect(fields.CustomField01).to.equal("egg")
			expect(fields.CustomField02).to.equal("night 2")
			expect(fields.CustomField03).to.equal(nil)
		end)

		it("is nil with no values and ignores values past the third", function()
			expect(AnalyticsRules.customFields(nil)).to.equal(nil)
			expect(AnalyticsRules.customFields({})).to.equal(nil)
			local fields = AnalyticsRules.customFields({ "a", "b", "c", "d" })
			expect(fields.CustomField03).to.equal("c")
			local count = 0
			for _ in fields do
				count += 1
			end
			expect(count).to.equal(3)
		end)

		it("caps each value's length", function()
			local fields = AnalyticsRules.customFields({ string.rep("y", 80) })
			expect(#fields.CustomField01).to.equal(AnalyticsRules.MAX_NAME_LENGTH)
		end)
	end)
end
