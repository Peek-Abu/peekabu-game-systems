--!strict
--[=[
	Unit tests for ItemContentRegistry — the boot-time item seeding both realms run.

	Both test runners (and both boot handlers) call ItemContentRegistry.init() before anything else, so these
	assertions double as a guard that the seeded starter set matches what the inventory specs and
	Cmdr item enum depend on. ItemRegistry.register now REJECTS double registration, so init()
	must guard its own re-entry (the test runner and this spec both call it).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemContentRegistry = require(script.Parent.ItemContentRegistry)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)

return function()
	describe("init", function()
		it("registers the starter set of items", function()
			ItemContentRegistry.init()

			local expectedTypes = {
				"rusted-saw",
				"phoenix-blade",
				"chambered-helmet",
				"healing-tonic",
				"throwing-knife",
				"wood",
				"crypt-key",
			}
			for _, itemType in expectedTypes do
				expect(ItemRegistry.isValidItemType(itemType)).to.equal(true)
			end
		end)

		it("registers two weapons with real display data", function()
			ItemContentRegistry.init()
			local rustedSaw = ItemRegistry.get("rusted-saw")
			expect(rustedSaw and rustedSaw.kind).to.equal("weapon")
			expect(rustedSaw and rustedSaw.rarity).to.equal("common")
			if rustedSaw and rustedSaw.kind == "weapon" then
				expect(rustedSaw.equipSlot).to.equal("weapon")
			end

			local phoenixBlade = ItemRegistry.get("phoenix-blade")
			expect(phoenixBlade and phoenixBlade.kind).to.equal("weapon")
			expect(phoenixBlade and phoenixBlade.rarity).to.equal("legendary")
			if phoenixBlade and phoenixBlade.kind == "weapon" then
				expect(phoenixBlade.equipSlot).to.equal("weapon")
			end
		end)

		it("registers an armour piece", function()
			ItemContentRegistry.init()
			local helmet = ItemRegistry.get("chambered-helmet")
			expect(helmet and helmet.kind).to.equal("armour")
			if helmet and helmet.kind == "armour" then
				expect(helmet.equipSlot).to.equal("helmet")
				expect(helmet.requiredLevel).to.equal(8)
				expect(helmet.statBonuses and helmet.statBonuses.rotEndurance).to.equal(8)
			end
		end)

		it("registers consumables with the documented stack shapes", function()
			ItemContentRegistry.init()

			local tonic = ItemRegistry.get("healing-tonic")
			expect(tonic and tonic.kind).to.equal("consumable")
			expect(ItemRegistry.isStackable("healing-tonic")).to.equal(true)
			if tonic and tonic.kind == "consumable" then
				expect(tonic.stackMax).to.equal(10)
			end

			local knife = ItemRegistry.get("throwing-knife")
			expect(knife and knife.kind).to.equal("consumable")
			if knife and knife.kind == "consumable" then
				expect(knife.stackMax).to.equal(10)
				expect(knife.maxStacks).to.equal(1)
			end
		end)

		it("registers misc items, one stackable and one a non-stackable quest item", function()
			ItemContentRegistry.init()

			local wood = ItemRegistry.get("wood")
			expect(wood and wood.kind).to.equal("misc")
			expect(ItemRegistry.isStackable("wood")).to.equal(true)
			if wood and wood.kind == "misc" then
				expect(wood.stackMax).to.equal(30)
			end

			local cryptKey = ItemRegistry.get("crypt-key")
			expect(cryptKey and cryptKey.kind).to.equal("misc")
			expect(ItemRegistry.isStackable("crypt-key")).to.equal(false)
			if cryptKey and cryptKey.kind == "misc" then
				expect(cryptKey.questItem).to.equal(true)
			end
		end)

		it("spreads rarities across the range, including one cursed item", function()
			ItemContentRegistry.init()
			local cryptKey = ItemRegistry.get("crypt-key")
			expect(cryptKey and cryptKey.rarity).to.equal("cursed")
		end)

		it("is idempotent — calling init again does not throw or corrupt definitions", function()
			expect(function()
				ItemContentRegistry.init()
				ItemContentRegistry.init()
			end).never.to.throw()
			local def = ItemRegistry.get("rusted-saw")
			expect(def and def.name).to.be.ok()
		end)
	end)
end
