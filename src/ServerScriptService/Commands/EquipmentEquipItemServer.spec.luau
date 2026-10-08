--!strict
--[=[
	Unit tests for the EquipItem Cmdr command implementation.
	Mock strategy: patch EquipmentService.equip inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local EquipmentService = require(ServerScriptService.Features.Equipment.EquipmentServiceServer)
local equipItemCommand = require(ServerScriptService.Commands.EquipmentEquipItemServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("EquipmentEquipItemServer", function()
		local _origEquip
		local calls: { { userId: number, uid: string } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_origEquip = EquipmentService.equip
			EquipmentService.equip = function(_self: any, userId: number, uid: string)
				table.insert(calls, { userId = userId, uid = uid })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			EquipmentService.equip = _origEquip
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards the target's UserId and the uid to the service", function()
			equipItemCommand(nil, fakePlayer, "i1")
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].uid).to.equal("i1")
		end)

		it("returns a success message on success and a failure message otherwise", function()
			local okMessage = equipItemCommand(nil, fakePlayer, "i1")
			expect(okMessage:find("Successfully")).to.be.ok()

			nextResult = false
			local failMessage = equipItemCommand(nil, fakePlayer, "i1")
			expect(failMessage:find("Failed")).to.be.ok()
		end)

		it("surfaces the service's specific failure reason in the response", function()
			nextResult = false
			nextReason = "requires level 8, you are level 3"
			local failMessage = equipItemCommand(nil, fakePlayer, "i1")
			expect(failMessage:find("requires level 8, you are level 3", 1, true)).to.be.ok()
		end)
	end)
end
