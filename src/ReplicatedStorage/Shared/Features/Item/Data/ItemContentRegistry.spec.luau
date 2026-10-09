--!strict
--[=[
	Unit tests for ItemContentRegistry — the boot-time item seeding both realms run.

	Both test runners (and both boot handlers) call ItemContentRegistry.init() before anything else, so these
	assertions double as a guard that the seeded sample catalog matches what the inventory specs and
	Cmdr item enum depend on. ItemRegistry.register REJECTS double registration, so init()
	must guard its own re-entry (the test runner and this spec both call it).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemContentRegistry = require(script.Parent.ItemContentRegistry)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)

return function()
	describe("init", function()
		it("registers the sample catalog of items", function()
			ItemContentRegistry.init()

			local expectedTypes = {
				"wrench",
				"golden-wrench",
				"hard-hat",
				"medkit",
				"flare",
				"scrap",
				"master-key",
			}
			for _, itemType in expectedTypes do
				expect(ItemRegistry.isValidItemType(itemType)).to.equal(true)
			end
		end)

		it("registers two unique tools with real display data", function()
			ItemContentRegistry.init()
			local wrench = ItemRegistry.get("wrench")
			expect(wrench and wrench.name).to.equal("Wrench")
			expect(wrench and wrench.kind).to.equal("tool")
			expect(wrench and wrench.rarity).to.equal("common")
			expect(wrench and wrench.icon).to.equal("rbxassetid://123")
			expect(wrench and wrench.description).to.equal("A sturdy wrench. Fixes most things, eventually.")
			expect(ItemRegistry.isStackable("wrench")).to.equal(false)

			local goldenWrench = ItemRegistry.get("golden-wrench")
			expect(goldenWrench and goldenWrench.name).to.equal("Golden Wrench")
			expect(goldenWrench and goldenWrench.kind).to.equal("tool")
			expect(goldenWrench and goldenWrench.rarity).to.equal("legendary")
			expect(goldenWrench and goldenWrench.icon).to.equal("rbxassetid://456")
			expect(goldenWrench and goldenWrench.description).to.equal("Too shiny to actually use.")
			expect(ItemRegistry.isStackable("golden-wrench")).to.equal(false)
		end)

		it("registers a unique wearable", function()
			ItemContentRegistry.init()
			local hardHat = ItemRegistry.get("hard-hat")
			expect(hardHat and hardHat.name).to.equal("Hard Hat")
			expect(hardHat and hardHat.kind).to.equal("wearable")
			expect(hardHat and hardHat.rarity).to.equal("epic")
			expect(hardHat and hardHat.icon).to.equal("rbxassetid://789")
			expect(hardHat and hardHat.description).to.equal("Safety first.")
			expect(ItemRegistry.isStackable("hard-hat")).to.equal(false)
		end)

		it("registers consumables with the documented stack shapes", function()
			ItemContentRegistry.init()

			local medkit = ItemRegistry.get("medkit")
			expect(medkit and medkit.name).to.equal("Medkit")
			expect(medkit and medkit.kind).to.equal("consumable")
			expect(medkit and medkit.rarity).to.equal("common")
			expect(medkit and medkit.icon).to.equal("rbxassetid://1011")
			expect(medkit and medkit.description).to.equal("Patches you up.")
			expect(ItemRegistry.isStackable("medkit")).to.equal(true)
			expect(medkit and medkit.stackMax).to.equal(10)
			expect(medkit and medkit.maxStacks).to.equal(nil)

			local flare = ItemRegistry.get("flare")
			expect(flare and flare.name).to.equal("Flare")
			expect(flare and flare.kind).to.equal("consumable")
			expect(flare and flare.rarity).to.equal("common")
			expect(flare and flare.icon).to.equal("rbxassetid://1213")
			expect(flare and flare.description).to.equal("Bright, brief, and limited to one stack.")
			expect(ItemRegistry.isStackable("flare")).to.equal(true)
			expect(flare and flare.stackMax).to.equal(10)
			expect(flare and flare.maxStacks).to.equal(1)
		end)

		it("registers misc items, one stackable and one unique", function()
			ItemContentRegistry.init()

			local scrap = ItemRegistry.get("scrap")
			expect(scrap and scrap.name).to.equal("Scrap")
			expect(scrap and scrap.kind).to.equal("misc")
			expect(scrap and scrap.rarity).to.equal("common")
			expect(scrap and scrap.icon).to.equal("rbxassetid://1415")
			expect(scrap and scrap.description).to.equal("Bits of metal. Someone will buy it.")
			expect(ItemRegistry.isStackable("scrap")).to.equal(true)
			expect(scrap and scrap.stackMax).to.equal(30)
			expect(scrap and scrap.maxStacks).to.equal(nil)

			local masterKey = ItemRegistry.get("master-key")
			expect(masterKey and masterKey.name).to.equal("Master Key")
			expect(masterKey and masterKey.kind).to.equal("misc")
			expect(masterKey and masterKey.rarity).to.equal("legendary")
			expect(masterKey and masterKey.icon).to.equal("rbxassetid://1617")
			expect(masterKey and masterKey.description).to.equal("Opens the door you were told not to open.")
			expect(ItemRegistry.isStackable("master-key")).to.equal(false)
		end)

		it("leaves the unique items without any stack fields", function()
			ItemContentRegistry.init()
			for _, itemType in { "wrench", "golden-wrench", "hard-hat", "master-key" } do
				local def = ItemRegistry.get(itemType)
				expect(def).to.be.ok()
				expect(def and def.stackMax).to.equal(nil)
				expect(def and def.maxStacks).to.equal(nil)
			end
		end)

		it("is idempotent — calling init again does not throw or corrupt definitions", function()
			expect(function()
				ItemContentRegistry.init()
				ItemContentRegistry.init()
			end).never.to.throw()
			local def = ItemRegistry.get("wrench")
			expect(def and def.name).to.equal("Wrench")
		end)
	end)
end
