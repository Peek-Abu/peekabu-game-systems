--[=[
	Unit tests for CustomizationEntitlementRules: the ownership gate every equip path runs. Uses real
	registry ids: FishingHat is a free accessory, WizardHat a lockable one.
]=]

local CustomizationEntitlementRules = require(script.Parent.CustomizationEntitlementRules)

local OWNS_WIZARD_HAT = { cosmetics = { accessory = { WizardHat = true } } }
local OWNS_NOTHING = { cosmetics = {} }

return function()
	describe("isUnlocked", function()
		it("passes a FREE cosmetic with no entitlements at all, even without a profile", function()
			expect(CustomizationEntitlementRules.isUnlocked(nil, "account", "accessory", "FishingHat")).to.equal(true)
		end)

		it("refuses a LOCKABLE cosmetic the account does not own", function()
			local ok, reason =
				CustomizationEntitlementRules.isUnlocked(OWNS_NOTHING, "account", "accessory", "WizardHat")
			expect(ok).to.equal(false)
			expect(reason:find("locked")).to.be.ok()
		end)

		it("passes a LOCKABLE cosmetic the account owns", function()
			expect(CustomizationEntitlementRules.isUnlocked(OWNS_WIZARD_HAT, "account", "accessory", "WizardHat")).to.equal(
				true
			)
		end)

		it("refuses a lockable cosmetic when no profile is loaded", function()
			local ok, reason = CustomizationEntitlementRules.isUnlocked(nil, "account", "accessory", "WizardHat")
			expect(ok).to.equal(false)
			expect(reason).to.equal("no profile loaded")
		end)

		it("refuses loudly for a per-slot scope, which is not implemented", function()
			local ok, reason =
				CustomizationEntitlementRules.isUnlocked(OWNS_WIZARD_HAT, "slot", "accessory", "WizardHat")
			expect(ok).to.equal(false)
			expect(reason:find("not implemented")).to.be.ok()
		end)
	end)

	describe("canEquip", function()
		it("refuses an id that is not registered in its category", function()
			local ok, reason =
				CustomizationEntitlementRules.canEquip(OWNS_WIZARD_HAT, "account", "accessory", "NoSuchHat")
			expect(ok).to.equal(false)
			expect(reason:find("not a registered")).to.be.ok()
		end)

		it("defers to isUnlocked for a registered id", function()
			expect(CustomizationEntitlementRules.canEquip(OWNS_NOTHING, "account", "accessory", "FishingHat")).to.equal(
				true
			)
			expect((CustomizationEntitlementRules.canEquip(OWNS_NOTHING, "account", "accessory", "WizardHat"))).to.equal(
				false
			)
		end)
	end)
end
