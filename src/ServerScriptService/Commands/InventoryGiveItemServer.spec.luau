--!strict
--[=[
	Unit tests for the GiveItem Cmdr command implementation.
	Mock strategy: patch InventoryService.addItem inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local giveItemCommand = require(ServerScriptService.Commands.InventoryGiveItemServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("InventoryGiveItemServer", function()
		local _origAddItem
		local calls: { { userId: number, itemType: string, count: number? } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_origAddItem = InventoryService.addItem
			InventoryService.addItem = function(_self: any, userId: number, itemType: string, count: number?)
				table.insert(calls, { userId = userId, itemType = itemType, count = count })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			InventoryService.addItem = _origAddItem
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards the target's UserId, itemType, and count to the service", function()
			giveItemCommand(nil, fakePlayer, "rusted-saw", 3)
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].itemType).to.equal("rusted-saw")
			expect(calls[1].count).to.equal(3)
		end)

		it("returns a success message on success and a failure message otherwise", function()
			local okMessage = giveItemCommand(nil, fakePlayer, "rusted-saw", 3)
			expect(okMessage:find("Successfully")).to.be.ok()

			nextResult = false
			local failMessage = giveItemCommand(nil, fakePlayer, "rusted-saw", 3)
			expect(failMessage:find("Failed")).to.be.ok()
		end)

		it("surfaces the service's specific failure reason in the response", function()
			nextResult = false
			nextReason = "would exceed the tool kind cap"
			local failMessage = giveItemCommand(nil, fakePlayer, "rusted-saw", 3)
			expect(failMessage:find("would exceed the tool kind cap", 1, true)).to.be.ok()
		end)
	end)
end
