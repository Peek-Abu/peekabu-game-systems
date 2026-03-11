--!strict
--[=[
	Unit tests for InventoryServiceClient — a thin read-facade over ClientStore.inventory.
	Seeds the atom directly and asserts the accessors read it. Replication is covered by the
	StateSync/ClientStore specs.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryServiceClient = require(ReplicatedStorage.Client.Services.InventoryService.InventoryServiceClient)
local ClientStore = require(ReplicatedStorage.Client.State.ClientStore)

return function()
	describe("InventoryServiceClient", function()
		afterEach(function()
			ClientStore.inventory({}) -- restore the empty default for other specs
		end)

		describe("getInventory", function()
			it("returns the inventory array from the store", function()
				ClientStore.inventory({ { itemType = "iron-sword", quantity = 3 } })
				local inv = InventoryServiceClient:getInventory()
				expect(#inv).to.equal(1)
				expect(inv[1].itemType).to.equal("iron-sword")
			end)

			it("returns an empty table before the first sync", function()
				ClientStore.inventory({})
				local inv = InventoryServiceClient:getInventory()
				expect(type(inv)).to.equal("table")
				expect(#inv).to.equal(0)
			end)
		end)

		describe("getState", function()
			it("reports the item count", function()
				ClientStore.inventory({
					{ itemType = "iron-sword", quantity = 3 },
					{ itemType = "phoenix-blade", instanceId = "i1" },
				})
				local state = InventoryServiceClient:getState()
				expect(state.itemCount).to.equal(2)
			end)
		end)
	end)
end
