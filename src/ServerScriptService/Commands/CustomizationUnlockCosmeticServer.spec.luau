--!strict
--[=[
	Unit tests for the UnlockCosmetic Cmdr command implementation.
	Mock strategy: patch CustomizationService.unlockCosmetic inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)
local unlockCosmeticCommand = require(ServerScriptService.Commands.CustomizationUnlockCosmeticServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("CustomizationUnlockCosmeticServer", function()
		local _origUnlock
		local calls: { { userId: number, category: string, id: string } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_origUnlock = CustomizationService.unlockCosmetic
			CustomizationService.unlockCosmetic = function(_self: any, userId: number, category: string, id: string)
				table.insert(calls, { userId = userId, category = category, id = id })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			CustomizationService.unlockCosmetic = _origUnlock
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards the target's UserId, category, and id to the service", function()
			unlockCosmeticCommand(nil, fakePlayer, "accessory", "WizardHat")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].category).to.equal("accessory")
			expect(calls[1].id).to.equal("WizardHat")
		end)

		it("returns a success message on success and a failure message otherwise", function()
			expect(unlockCosmeticCommand(nil, fakePlayer, "accessory", "WizardHat"):find("Unlocked")).to.be.ok()
			nextResult = false
			expect(unlockCosmeticCommand(nil, fakePlayer, "accessory", "WizardHat"):find("Failed")).to.be.ok()
		end)

		it("surfaces the service's specific failure reason", function()
			nextResult = false
			nextReason = '"FishingHat" is free — it needs no unlock'
			local message = unlockCosmeticCommand(nil, fakePlayer, "accessory", "FishingHat")
			expect(message:find("is free", 1, true)).to.be.ok()
		end)
	end)
end
