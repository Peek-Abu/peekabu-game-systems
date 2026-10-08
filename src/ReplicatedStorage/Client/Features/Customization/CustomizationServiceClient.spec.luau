--!strict
--[=[
	Unit tests for CustomizationServiceClient — the thin read facade over StateSyncClientStore.appearance /
	StateSyncClientStore.entitlements. Seeds the atoms directly (charm-sync's job in production) and asserts the
	facade hands the values back, plus the display-only isUnlocked mirror of the server's gate.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationServiceClient = require(ReplicatedStorage.Client.Features.Customization.CustomizationServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

return function()
	local function reset()
		StateSyncClientStore.appearance({
			cosmetics = {},
			accessories = {},
			body = {},
			headType = "Uncovered",
			surfaces = {},
		})
		StateSyncClientStore.entitlements({ cosmetics = {} })
	end

	beforeEach(reset)
	afterEach(reset)

	describe("getAppearance", function()
		it("returns an empty appearance before the first sync", function()
			local appearance = CustomizationServiceClient:getAppearance()
			expect(next(appearance.cosmetics)).to.equal(nil)
			expect(#appearance.accessories).to.equal(0)
		end)

		it("returns the appearance from the store", function()
			StateSyncClientStore.appearance({
				cosmetics = { hair = { id = "Hair2", colors = {} } },
				accessories = {},
				body = {},
			})
			expect(CustomizationServiceClient:getAppearance().cosmetics.hair.id).to.equal("Hair2")
		end)
	end)

	describe("getEntitlements", function()
		it("returns the entitlements from the store", function()
			StateSyncClientStore.entitlements({ cosmetics = { accessory = { WizardHat = true } } })
			expect(CustomizationServiceClient:getEntitlements().cosmetics.accessory.WizardHat).to.equal(true)
		end)
	end)

	describe("soul colour", function()
		it("returns nil before one is set", function()
			expect(CustomizationServiceClient:getSoulColor()).to.equal(nil)
			expect(CustomizationServiceClient:getSoulColorGradient()).to.equal(nil)
		end)

		it("returns the synced id and its resolved gradient", function()
			StateSyncClientStore.appearance({
				cosmetics = {},
				accessories = {},
				body = {},
				headType = "Uncovered",
				surfaces = {},
				soulColor = "white-black",
			})

			expect(CustomizationServiceClient:getSoulColor()).to.equal("white-black")
			local stops = CustomizationServiceClient:getSoulColorGradient()
			expect(#stops).to.equal(2)
			expect(stops[1].color.r).to.equal(255)
			expect(stops[2].color.r).to.equal(0)
		end)

		-- Tolerance, matching the rest of the system: a since-retired id must not break a UI read.
		it("returns nil gradient for an id that is no longer registered", function()
			StateSyncClientStore.appearance({
				cosmetics = {},
				accessories = {},
				body = {},
				headType = "Uncovered",
				surfaces = {},
				soulColor = "chartreuse",
			})
			expect(CustomizationServiceClient:getSoulColor()).to.equal("chartreuse")
			expect(CustomizationServiceClient:getSoulColorGradient()).to.equal(nil)
		end)
	end)

	describe("isUnlocked", function()
		it("is always true for a FREE cosmetic, with no entitlement needed", function()
			expect(CustomizationServiceClient:isUnlocked("accessory", "FishingHat")).to.equal(true)
			expect(CustomizationServiceClient:isUnlocked("hair", "Hair2")).to.equal(true)
		end)

		it("is false for a LOCKABLE cosmetic that is not owned", function()
			expect(CustomizationServiceClient:isUnlocked("accessory", "WizardHat")).to.equal(false)
		end)

		it("is true for a LOCKABLE cosmetic once the account owns it", function()
			StateSyncClientStore.entitlements({ cosmetics = { accessory = { WizardHat = true } } })
			expect(CustomizationServiceClient:isUnlocked("accessory", "WizardHat")).to.equal(true)
		end)
	end)
end
