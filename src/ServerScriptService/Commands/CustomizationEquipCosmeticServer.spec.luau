--!strict
--[=[
	Unit tests for the EquipCosmetic Cmdr command implementation.
	Mock strategy: patch the service methods inside beforeAll/afterAll (see AddCurrencyServer.spec for
	the rationale). The branch that matters here is the category routing: "accessory" is slot-indexed,
	every other category is a single selection.
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local CustomizationService = require(ServerScriptService.Features.Customization.CustomizationServiceServer)
local equipCosmeticCommand = require(ServerScriptService.Commands.CustomizationEquipCosmeticServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("CustomizationEquipCosmeticServer", function()
		local _origEquipCosmetic
		local _origEquipAccessory
		local cosmeticCalls: { { userId: number, category: string, id: string } } = {}
		local accessoryCalls: { { userId: number, slot: number, id: string } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_origEquipCosmetic = CustomizationService.equipCosmetic
			_origEquipAccessory = CustomizationService.equipAccessory
			CustomizationService.equipCosmetic = function(_self: any, userId: number, category: string, id: string)
				table.insert(cosmeticCalls, { userId = userId, category = category, id = id })
				return nextResult, nextReason
			end
			CustomizationService.equipAccessory = function(_self: any, userId: number, slot: number, id: string)
				table.insert(accessoryCalls, { userId = userId, slot = slot, id = id })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			CustomizationService.equipCosmetic = _origEquipCosmetic
			CustomizationService.equipAccessory = _origEquipAccessory
		end)

		beforeEach(function()
			cosmeticCalls = {}
			accessoryCalls = {}
			nextResult = true
			nextReason = nil
		end)

		it("routes a non-accessory category to equipCosmetic, ignoring the slot", function()
			equipCosmeticCommand(nil, fakePlayer, "hair", "Hair2", 3)
			expect(#cosmeticCalls).to.equal(1)
			expect(#accessoryCalls).to.equal(0)
			expect(cosmeticCalls[1].userId).to.equal(42)
			expect(cosmeticCalls[1].category).to.equal("hair")
			expect(cosmeticCalls[1].id).to.equal("Hair2")
		end)

		it("routes the accessory category to equipAccessory with the slot", function()
			equipCosmeticCommand(nil, fakePlayer, "accessory", "WizardHat", 2)
			expect(#accessoryCalls).to.equal(1)
			expect(#cosmeticCalls).to.equal(0)
			expect(accessoryCalls[1].slot).to.equal(2)
			expect(accessoryCalls[1].id).to.equal("WizardHat")
		end)

		it("returns a success message on success and a failure message otherwise", function()
			expect(equipCosmeticCommand(nil, fakePlayer, "hair", "Hair2", 1):find("Equipped")).to.be.ok()
			nextResult = false
			expect(equipCosmeticCommand(nil, fakePlayer, "hair", "Hair2", 1):find("Failed")).to.be.ok()
		end)

		it("surfaces the service's specific failure reason", function()
			nextResult = false
			nextReason = '"WizardHat" is locked — unlock it before equipping'
			local message = equipCosmeticCommand(nil, fakePlayer, "accessory", "WizardHat", 1)
			expect(message:find("is locked", 1, true)).to.be.ok()
		end)
	end)
end
