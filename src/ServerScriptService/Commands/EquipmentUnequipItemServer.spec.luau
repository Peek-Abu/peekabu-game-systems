--!strict
--[=[
	Unit tests for the UnequipItem Cmdr command implementation.
	Mock strategy: patch EquipmentService.unequip inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local EquipmentService = require(ServerScriptService.Features.Equipment.EquipmentServiceServer)
local unequipItemCommand = require(ServerScriptService.Commands.EquipmentUnequipItemServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("EquipmentUnequipItemServer", function()
		local _origUnequip
		local calls: { { userId: number, slotId: string } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_origUnequip = EquipmentService.unequip
			EquipmentService.unequip = function(_self: any, userId: number, slotId: string)
				table.insert(calls, { userId = userId, slotId = slotId })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			EquipmentService.unequip = _origUnequip
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards the target's UserId and the slotId to the service", function()
			unequipItemCommand(nil, fakePlayer, "helmet")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].slotId).to.equal("helmet")
		end)

		it("returns a success message on success and a failure message otherwise", function()
			local okMessage = unequipItemCommand(nil, fakePlayer, "helmet")
			expect(okMessage:find("Successfully")).to.be.ok()

			nextResult = false
			local failMessage = unequipItemCommand(nil, fakePlayer, "helmet")
			expect(failMessage:find("Failed")).to.be.ok()
		end)

		it("surfaces the service's specific failure reason in the response", function()
			nextResult = false
			nextReason = 'slot "helmet" is empty'
			local failMessage = unequipItemCommand(nil, fakePlayer, "helmet")
			expect(failMessage:find('slot "helmet" is empty', 1, true)).to.be.ok()
		end)
	end)
end
