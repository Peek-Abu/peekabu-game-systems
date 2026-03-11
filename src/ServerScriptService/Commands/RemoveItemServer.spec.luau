--!strict
--[=[
	Unit tests for the RemoveItem Cmdr command implementation.
	Mock strategy: patch InventoryService.removeItem inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService.Services.InventoryService.InventoryServiceServer)
local removeItemCommand = require(ServerScriptService.Commands.RemoveItemServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("RemoveItemServer", function()
		local _origRemoveItem
		local calls: { { userId: number, targetItem: any, amount: number } } = {}
		local nextResult = true

		beforeAll(function()
			_origRemoveItem = InventoryService.removeItem
			InventoryService.removeItem = function(_self: any, userId: number, targetItem: any, amount: number)
				table.insert(calls, { userId = userId, targetItem = targetItem, amount = amount })
				return nextResult
			end
		end)

		afterAll(function()
			InventoryService.removeItem = _origRemoveItem
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
		end)

		it("forwards the target's UserId, item matcher, and amount to the service", function()
			removeItemCommand(nil, fakePlayer, "iron-sword", 2)
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].targetItem.itemType).to.equal("iron-sword")
			expect(calls[1].amount).to.equal(2)
		end)

		it("returns a success message on success and a failure message otherwise", function()
			local okMessage = removeItemCommand(nil, fakePlayer, "iron-sword", 2)
			expect(okMessage:find("Successfully")).to.be.ok()

			nextResult = false
			local failMessage = removeItemCommand(nil, fakePlayer, "iron-sword", 2)
			expect(failMessage:find("Failed")).to.be.ok()
		end)
	end)
end
