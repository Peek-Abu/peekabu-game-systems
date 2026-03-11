--!strict
--[=[
	Unit tests for ItemDefinitions — the runtime item-type registry.

	The backing map is module-global and shared with other specs (the inventory specs rely on
	GameItems.init() having registered "iron-sword"/"phoenix-blade"), so these tests register only
	uniquely-named spec items and never remove anything.
]=]

local ItemDefinitions = require(script.Parent.ItemDefinitions)

return function()
	describe("register / get", function()
		it("registers a definition and returns it by type", function()
			ItemDefinitions.register("spec-test-item", {
				name = "Spec Test Item",
				icon = "rbxassetid://0",
				rarity = "Common",
			})
			local def = ItemDefinitions.get("spec-test-item")
			expect(def).to.be.ok()
			expect(def and def.name).to.equal("Spec Test Item")
		end)

		it("overwrites an existing definition on re-register", function()
			ItemDefinitions.register("spec-overwrite-item", {
				name = "Before",
				icon = "rbxassetid://0",
				rarity = "Common",
			})
			ItemDefinitions.register("spec-overwrite-item", {
				name = "After",
				icon = "rbxassetid://0",
				rarity = "Rare",
			})
			local def = ItemDefinitions.get("spec-overwrite-item")
			expect(def and def.name).to.equal("After")
		end)

		it("returns nil for an unregistered type", function()
			expect(ItemDefinitions.get("spec-never-registered")).to.equal(nil)
		end)
	end)

	describe("isValidItemType", function()
		it("is true for a registered type and false otherwise", function()
			ItemDefinitions.register("spec-valid-item", {
				name = "Valid",
				icon = "rbxassetid://0",
				rarity = "Common",
			})
			expect(ItemDefinitions.isValidItemType("spec-valid-item")).to.equal(true)
			expect(ItemDefinitions.isValidItemType("spec-never-registered")).to.equal(false)
		end)
	end)

	describe("getValidItemTypes", function()
		it("includes every registered type", function()
			ItemDefinitions.register("spec-enum-item", {
				name = "Enum Item",
				icon = "rbxassetid://0",
				rarity = "Common",
			})
			local seen: { [string]: boolean } = {}
			for _, itemType in ItemDefinitions.getValidItemTypes() do
				seen[itemType] = true
			end
			expect(seen["spec-enum-item"]).to.equal(true)
		end)
	end)
end
