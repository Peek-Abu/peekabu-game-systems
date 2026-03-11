--!strict
--[=[
	Unit tests for the GiveItem Cmdr command implementation.
	Mock strategy: patch InventoryService.addItem inside beforeAll/afterAll (see
	AddCurrencyServer.spec for the rationale).
]=]

local ServerScriptService = game:GetService("ServerScriptService")

local InventoryService = require(ServerScriptService.Services.InventoryService.InventoryServiceServer)
local giveItemCommand = require(ServerScriptService.Commands.GiveItemServer)

local fakePlayer = { UserId = 42, Name = "TestPlayer" } :: any

return function()
	describe("GiveItemServer", function()
		local _origAddItem
		local calls: { { userId: number, item: any } } = {}
		local nextResult = true

		beforeAll(function()
			_origAddItem = InventoryService.addItem
			InventoryService.addItem = function(_self: any, userId: number, item: any)
				table.insert(calls, { userId = userId, item = item })
				return nextResult
			end
		end)

		afterAll(function()
			InventoryService.addItem = _origAddItem
		end)

		beforeEach(function()
			calls = {}
			nextResult = true
		end)

		it("forwards the target's UserId and a well-formed item to the service", function()
			giveItemCommand(nil, fakePlayer, "iron-sword", 3)
			expect(#calls).to.equal(1)
			expect(calls[1].userId).to.equal(42)
			expect(calls[1].item.itemType).to.equal("iron-sword")
			expect(calls[1].item.quantity).to.equal(3)
		end)

		it("returns a success message on success and a failure message otherwise", function()
			local okMessage = giveItemCommand(nil, fakePlayer, "iron-sword", 3)
			expect(okMessage:find("Successfully")).to.be.ok()

			nextResult = false
			local failMessage = giveItemCommand(nil, fakePlayer, "iron-sword", 3)
			expect(failMessage:find("Failed")).to.be.ok()
		end)
	end)
end
