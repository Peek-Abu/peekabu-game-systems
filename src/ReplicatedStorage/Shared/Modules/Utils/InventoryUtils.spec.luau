--!strict
--[=[
	Unit tests for InventoryUtils module.
	Tests item expansion, finding, adding, and removing.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryUtils = require(script.Parent.InventoryUtils)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

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

		it("rejects a non-positive quantity instead of stacking it", function()
			-- The beforeEach seeds one iron-sword stack of 5. A negative/zero quantity would otherwise
			-- stack into a negative or junk-zero entry; it must be rejected and leave the stack at 5.
			local negative = InventoryUtils.tryAdd(inventory, { itemType = "iron-sword", quantity = -100 })
			expect(negative.success).to.equal(false)
			expect(negative.action).to.equal("rejected")

			local zero = InventoryUtils.tryAdd(inventory, { itemType = "iron-sword", quantity = 0 })
			expect(zero.success).to.equal(false)
			expect(zero.action).to.equal("rejected")

			-- The existing stack is untouched by either rejected add.
			expect(inventory[1].quantity).to.equal(5)
		end)

		it("stores an independent copy, not a reference to the passed-in item", function()
			local item: PlayerDataTypes.InventoryItem = { itemType = "phoenix-blade", quantity = 1 }
			local result = InventoryUtils.tryAdd(inventory, item)
			expect(result.success).to.equal(true)

			-- Mutating the caller's item AFTER the add must not change what's in the inventory.
			item.quantity = 999
			local storedIdx = InventoryUtils.findMatchingItemIndex(inventory, { itemType = "phoenix-blade" })
			expect(inventory[storedIdx :: number].quantity).to.equal(1)
			-- ...and the returned snapshot is likewise decoupled from the caller's item.
			expect(result.resultItem).never.to.equal(item)
			expect((result.resultItem :: PlayerDataTypes.InventoryItem).quantity).to.equal(1)
		end)

		it("adds a stackable item without colliding with a unique instance of the same type", function()
			-- A unique "iron-sword" instance coexisting with the stackable stack must NOT cause a
			-- stackable add to be rejected as a duplicate — they are distinct entries.
			table.insert(inventory, { itemType = "iron-sword", instanceId = "unique-sword-1" })

			local result = InventoryUtils.tryAdd(inventory, { itemType = "iron-sword", quantity = 2 })
			expect(result.success).to.equal(true)
			expect(result.action).to.equal("update") -- stacked onto the stackable entry (idx 1)...
			expect(inventory[1].quantity).to.equal(7)
			-- ...and the unique instance is untouched.
			local uniqueIdx = InventoryUtils.findMatchingItemIndex(
				inventory,
				{ itemType = "iron-sword", instanceId = "unique-sword-1" }
			)
			expect(uniqueIdx).to.be.ok()
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
			-- The snapshot reports the amount that LEFT the inventory (10), not a zero-quantity leftover.
			expect((result.resultItem :: PlayerDataTypes.InventoryItem).quantity).to.equal(10)
		end)

		it("removes a stackable stack by itemType without touching a unique of the same type", function()
			-- Seed a unique iron-sword instance alongside the stackable stack of 10.
			table.insert(inventory, { itemType = "iron-sword", instanceId = "unique-sword-1" })

			-- Removing by type alone (no instanceId) must target the stackable stack, never the unique.
			local result = InventoryUtils.tryRemove(inventory, { itemType = "iron-sword" }, 10)
			expect(result.success).to.equal(true)
			expect(result.action).to.equal("remove")
			-- The unique instance survives.
			local uniqueIdx = InventoryUtils.findMatchingItemIndex(
				inventory,
				{ itemType = "iron-sword", instanceId = "unique-sword-1" }
			)
			expect(uniqueIdx).to.be.ok()
		end)

		it("should decrement quantity for partial removal", function()
			local item: PlayerDataTypes.InventoryItem = { itemType = "iron-sword" }

			local result = InventoryUtils.tryRemove(inventory, item, 3)

			expect(result.success).to.equal(true)
			expect(result.action).to.equal("update")
			expect(inventory[1].quantity).to.equal(7)
			-- resultItem is a snapshot at the remaining quantity, not the live entry: it carries 7,
			-- and mutating it does not change the stored stack.
			local snapshot = result.resultItem :: PlayerDataTypes.InventoryItem
			expect(snapshot).never.to.equal(inventory[1])
			expect(snapshot.quantity).to.equal(7)
			snapshot.quantity = 0
			expect(inventory[1].quantity).to.equal(7)
		end)

		it("should return insufficient for not enough quantity", function()
			local item: PlayerDataTypes.InventoryItem = { itemType = "iron-sword" }

			local result = InventoryUtils.tryRemove(inventory, item, 20)

			expect(result.success).to.equal(false)
			expect(result.action).to.equal("insufficient")
		end)

		it("should remove a unique item when amount is 1", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "phoenix-blade",
				instanceId = "unique-123",
			}

			local result = InventoryUtils.tryRemove(inventory, item, 1)

			expect(result.success).to.equal(true)
			expect(result.action).to.equal("remove")
			expect(#inventory).to.equal(1)
		end)

		it("should return insufficient when removing more than one of a unique item", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "phoenix-blade",
				instanceId = "unique-123",
			}

			local result = InventoryUtils.tryRemove(inventory, item, 2)

			expect(result.success).to.equal(false)
			expect(result.action).to.equal("insufficient")
			-- The unique item must NOT be removed when the request can't be satisfied.
			expect(#inventory).to.equal(2)
		end)

		it("should return not_found for non-existent item", function()
			local item: PlayerDataTypes.InventoryItem = {
				itemType = "phoenix-blade",
				instanceId = "different-id",
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
