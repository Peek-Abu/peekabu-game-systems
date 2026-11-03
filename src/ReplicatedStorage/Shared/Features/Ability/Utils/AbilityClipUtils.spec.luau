local AbilityClipUtils = require(script.Parent.AbilityClipUtils)

local BOTH = { full = "rally", upper = "rallyupper" }

return function()
	describe("pick", function()
		it("plays the full-body clip standing still with empty hands", function()
			local key, kind = AbilityClipUtils.pick(BOTH, false, false)
			expect(key).to.equal("rally")
			expect(kind).to.equal("full")
		end)

		it("plays the upper-body clip while moving", function()
			local key, kind = AbilityClipUtils.pick(BOTH, true, false)
			expect(key).to.equal("rallyupper")
			expect(kind).to.equal("upper")
		end)

		it("plays nothing while the hands are busy (the vacuum out, something carried)", function()
			expect(AbilityClipUtils.pick(BOTH, false, true)).to.equal(nil)
			expect(AbilityClipUtils.pick(BOTH, true, true)).to.equal(nil)
		end)

		it("skips the clip while moving when the ability has no upper-body cut", function()
			expect(AbilityClipUtils.pick({ full = "rally" }, true, false)).to.equal(nil)
			local key, kind = AbilityClipUtils.pick({ full = "rally" }, false, false)
			expect(key).to.equal("rally")
			expect(kind).to.equal("full")
		end)

		it("plays the upper-body cut standing still when there is no full one", function()
			local key, kind = AbilityClipUtils.pick({ upper = "rallyupper" }, false, false)
			expect(key).to.equal("rallyupper")
			expect(kind).to.equal("upper")
		end)

		it("plays nothing for an ability with no clips", function()
			expect(AbilityClipUtils.pick({}, false, false)).to.equal(nil)
		end)
	end)

	describe("keeps", function()
		it("stops a full-body clip once its user moves or busies their hands", function()
			expect(AbilityClipUtils.keeps("full", false, false)).to.equal(true)
			expect(AbilityClipUtils.keeps("full", true, false)).to.equal(false)
			expect(AbilityClipUtils.keeps("full", false, true)).to.equal(false)
		end)

		it("keeps an upper-body clip on the move, never with busy hands", function()
			expect(AbilityClipUtils.keeps("upper", true, false)).to.equal(true)
			expect(AbilityClipUtils.keeps("upper", false, false)).to.equal(true)
			expect(AbilityClipUtils.keeps("upper", true, true)).to.equal(false)
		end)
	end)
end
