--!strict
--[=[
	Unit tests for InventoryUtils module.
	Tests item expansion, finding, adding, and removing.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryUtils = require(script.Parent.InventoryUtils)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local ItemDefinitions = require(ReplicatedStorage.Shared.Modules.ItemDefinitions)

return function()
	describe("expandItem", function()
		it("should merge item data with definition", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "iron-sword",
				quantity = 5,
			}

			local expanded = InventoryUtils.expandItem(item)

			expect(expanded.itemType).to.equal("iron-sword")
			expect(expanded.quantity).to.equal(5)
			expect(expanded.name).to.equal("Iron Blade")
			expect(expanded.rarity).to.equal("Common")
		end)

		it("should handle items without definitions", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "unknown-item",
				quantity = 1,
			}

			local expanded = InventoryUtils.expandItem(item)
			expect(expanded.itemType).to.equal("unknown-item")
		end)
	end)

	describe("expandAll", function()
		it("should expand all items in array", function()
			local items: { PlayerDataTypes.InventoryItem } = {
				{ itemType = "iron-sword", quantity = 5 },
				{ itemType = "phoenix-blade", quantity = 1 },
			}

			local expanded = InventoryUtils.expandAll(items)

			expect(#expanded).to.equal(2)
			expect(expanded[1].name).to.equal("Iron Blade")
			expect(expanded[2].name).to.equal("Phoenix Blade")
		end)

		it("should handle empty array", function()
			local expanded = InventoryUtils.expandAll({})
			expect(#expanded).to.equal(0)
		end)
	end)

	describe("findMatchingItemIndex", function()
		local inventory: { PlayerDataTypes.InventoryItem }

		beforeEach(function()
			inventory = {
				{ itemType = "iron-sword", quantity = 5 },
				{ itemType = "phoenix-blade", quantity = 1, instanceId = "unique-123" },
			}
		end)

		it("should find stackable item by itemType", function()
			local item: PlayerDataTypes.InventoryItem = { itemType = "iron-sword" }
			local index = InventoryUtils.findMatchingItemIndex(inventory, item)
			expect(index).to.equal(1)
		end)

		it("should find unique item by itemType and instanceId", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "phoenix-blade",
				instanceId = "unique-123",
			}
			local index = InventoryUtils.findMatchingItemIndex(inventory, item)
			expect(index).to.equal(2)
		end)

		it("should return nil for non-existent item", function()
			local item: PlayerDataTypes.InventoryItem = { itemType = "non-existent" }
			local index = InventoryUtils.findMatchingItemIndex(inventory, item)
			expect(index).to.equal(nil)
		end)

		it("should not match unique item with different instanceId", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "phoenix-blade",
				instanceId = "different-id",
			}
			local index = InventoryUtils.findMatchingItemIndex(inventory, item)
			expect(index).to.equal(nil)
		end)
	end)

	describe("tryAdd", function()
		local inventory: { PlayerDataTypes.InventoryItem }

		beforeEach(function()
			inventory = {
				{ itemType = "iron-sword", quantity = 5 },
			}
		end)

		it("should add new item", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "phoenix-blade",
				quantity = 1,
			}

			local result = InventoryUtils.tryAdd(inventory, item)

			expect(result.success).to.equal(true)
			expect(result.action).to.equal("add")
			expect(#inventory).to.equal(2)
		end)

		it("should stack quantities for existing stackable item", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "iron-sword",
				quantity = 3,
			}

			local result = InventoryUtils.tryAdd(inventory, item)

			expect(result.success).to.equal(true)
			expect(result.action).to.equal("update")
			expect(inventory[1].quantity).to.equal(8)
			expect(#inventory).to.equal(1)
		end)

		it("should reject duplicate unique items", function()
			table.insert(inventory, {
				itemType = "phoenix-blade",
				instanceId = "unique-123",
			})

			local item: PlayerDataTypes.InventoryItem = {
				itemType = "phoenix-blade",
				instanceId = "unique-123",
			}

			local result = InventoryUtils.tryAdd(inventory, item)

			expect(result.success).to.equal(false)
			expect(result.action).to.equal("rejected")
		end)

		it("should throw error for invalid item type", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "invalid-item",
				quantity = 1,
			}

			expect(function()
				InventoryUtils.tryAdd(inventory, item)
			end).to.throw()
		end)
	end)

	describe("tryRemove", function()
		local inventory: { PlayerDataTypes.InventoryItem }

		beforeEach(function()
			inventory = {
				{ itemType = "iron-sword", quantity = 10 },
				{ itemType = "phoenix-blade", instanceId = "unique-123" },
			}
		end)

		it("should remove stackable item completely when quantity reaches 0", function()
			local item: PlayerDataTypes.InventoryItem = { itemType = "iron-sword" }

			local result = InventoryUtils.tryRemove(inventory, item, 10)

			expect(result.success).to.equal(true)
			expect(result.action).to.equal("remove")
			expect(#inventory).to.equal(1)
		end)

		it("should decrement quantity for partial removal", function()
			local item: PlayerDataTypes.InventoryItem = { itemType = "iron-sword" }

			local result = InventoryUtils.tryRemove(inventory, item, 3)

			expect(result.success).to.equal(true)
			expect(result.action).to.equal("update")
			expect(inventory[1].quantity).to.equal(7)
		end)

		it("should return insufficient for not enough quantity", function()
			local item: PlayerDataTypes.InventoryItem = { itemType = "iron-sword" }

			local result = InventoryUtils.tryRemove(inventory, item, 20)

			expect(result.success).to.equal(false)
			expect(result.action).to.equal("insufficient")
		end)

		it("should remove unique item regardless of amount", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "phoenix-blade",
				instanceId = "unique-123",
			}

			local result = InventoryUtils.tryRemove(inventory, item, 1)

			expect(result.success).to.equal(true)
			expect(result.action).to.equal("remove")
			expect(#inventory).to.equal(1)
		end)

		it("should return not_found for non-existent item", function()
			local item: PlayerDataTypes.InventoryItem = { 
				itemType = "phoenix-blade",
				instanceId = "different-id"
			}

			local result = InventoryUtils.tryRemove(inventory, item, 1)

			expect(result.success).to.equal(false)
			expect(result.action).to.equal("not_found")
		end)

		it("should throw error for non-positive amount", function()
			local item: PlayerDataTypes.InventoryItem = { itemType = "iron-sword" }

			expect(function()
				InventoryUtils.tryRemove(inventory, item, 0)
			end).to.throw()
		end)
	end)

	describe("add", function()
		it("should add item without returning result", function()
			local inventory: { PlayerDataTypes.InventoryItem } = {}
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "iron-sword",
				quantity = 5,
			}

			InventoryUtils.add(inventory, item)

			expect(#inventory).to.equal(1)
			expect(inventory[1].itemType).to.equal("iron-sword")
		end)
	end)

	describe("remove", function()
		it("should remove item completely", function()
			local inventory: { PlayerDataTypes.InventoryItem } = {
				{ itemType = "iron-sword", quantity = 5 },
			}

			local item: PlayerDataTypes.InventoryItem = { itemType = "iron-sword" }

			InventoryUtils.remove(inventory, item)

			expect(#inventory).to.equal(0)
		end)

		it("should handle removing non-existent item gracefully", function()
			local inventory: { PlayerDataTypes.InventoryItem } = {}
			local item: PlayerDataTypes.InventoryItem = { itemType = "iron-sword" }

			expect(function()
				InventoryUtils.remove(inventory, item)
			end).never.to.throw()

			expect(#inventory).to.equal(0)
		end)
	end)
end
