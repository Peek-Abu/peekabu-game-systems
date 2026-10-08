--!strict
--[=[
	Unit tests for the RemoveItem Cmdr command implementation.
	Mock strategy: patch InventoryService.removeItem inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local removeItemCommand = require(ServerScriptService.Commands.InventoryRemoveItemServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("InventoryRemoveItemServer", function()
		local _origRemoveItem
		local calls: { { userId: number, spec: any } } = {}
		local nextResult = true
		local nextReason: string? = nil

		beforeAll(function()
			_origRemoveItem = InventoryService.removeItem
			InventoryService.removeItem = function(_self: any, userId: number, spec: any)
				table.insert(calls, { userId = userId, spec = spec })
				return nextResult, nextReason
			end
		end)

		afterAll(function()
			InventoryService.removeItem = _origRemoveItem
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
			nextReason = nil
		end)

		it("forwards the target's UserId and an itemType + quantity spec to the service", function()
			removeItemCommand(nil, fakePlayer, "rusted-saw", 2)
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].spec.itemType).to.equal("rusted-saw")
			expect(calls[1].spec.quantity).to.equal(2)
		end)

		it("returns a success message on success and a failure message otherwise", function()
			local okMessage = removeItemCommand(nil, fakePlayer, "rusted-saw", 2)
			expect(okMessage:find("Successfully")).to.be.ok()

			nextResult = false
			local failMessage = removeItemCommand(nil, fakePlayer, "rusted-saw", 2)
			expect(failMessage:find("Failed")).to.be.ok()
		end)

		it("surfaces the service's specific failure reason in the response", function()
			nextResult = false
			nextReason = "insufficient quantity"
			local failMessage = removeItemCommand(nil, fakePlayer, "rusted-saw", 2)
			expect(failMessage:find("insufficient quantity", 1, true)).to.be.ok()
		end)
	end)
end
