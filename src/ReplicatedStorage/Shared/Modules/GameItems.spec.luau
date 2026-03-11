--!strict
--[=[
	Unit tests for GameItems — the boot-time item seeding both realms run.

	Both test runners (and both boot handlers) call GameItems.init() before anything else, so these
	assertions double as a guard that the seeded registry matches what the inventory specs and Cmdr
	item enum depend on.
]=]

local GameItems = require(script.Parent.GameItems)
local ItemDefinitions = require(script.Parent.ItemDefinitions)

return function()
	describe("init", function()
		it("registers the built-in item definitions", function()
			GameItems.init()
			expect(ItemDefinitions.isValidItemType("iron-sword")).to.equal(true)
			expect(ItemDefinitions.isValidItemType("phoenix-blade")).to.equal(true)

			local ironSword = ItemDefinitions.get("iron-sword")
			expect(ironSword and ironSword.rarity).to.equal("Common")
			local phoenixBlade = ItemDefinitions.get("phoenix-blade")
			expect(phoenixBlade and phoenixBlade.rarity).to.equal("Legendary")
		end)

		it("is idempotent — calling init again does not throw or corrupt definitions", function()
			expect(function()
				GameItems.init()
				GameItems.init()
			end).never.to.throw()
			local def = ItemDefinitions.get("iron-sword")
			expect(def and def.name).to.equal("Iron Blade")
		end)
	end)
end
