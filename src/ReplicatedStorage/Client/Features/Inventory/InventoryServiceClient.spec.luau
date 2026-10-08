--!strict
--[=[
	Unit tests for InventoryServiceClient — a thin read-facade over StateSyncClientStore.inventory.
	Seeds the atom directly and asserts the accessors read it. Replication is covered by the
	StateSync/StateSyncClientStore specs.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryServiceClient = require(ReplicatedStorage.Client.Features.Inventory.InventoryServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local ItemConstants = require(ReplicatedStorage.Shared.Features.Item.Data.ItemConstants)

return function()
	describe("InventoryServiceClient", function()
		beforeAll(function()
			-- Idempotent: ItemContentRegistry.init() no-ops if already seeded in this VM. getEntriesOfKind
			-- delegates to InventoryUtils.entriesOfKind, which asks the registry for each itemType's
			-- kind, so the starter set must be registered for the kind filter to resolve.
			ItemContentRegistry.init()
		end)

		afterEach(function()
			StateSyncClientStore.inventory({ items = {} }) -- restore the empty default for other specs
		end)

		describe("getInventory", function()
			it("returns the inventory wrapper from the store", function()
				StateSyncClientStore.inventory({ items = { { itemType = "rusted-saw", quantity = 3 } } })
				local inv = InventoryServiceClient:getInventory()
				expect(#inv.items).to.equal(1)
				expect(inv.items[1].itemType).to.equal("rusted-saw")
			end)

			it("returns an empty items table before the first sync", function()
				StateSyncClientStore.inventory({ items = {} })
				local inv = InventoryServiceClient:getInventory()
				expect(type(inv.items)).to.equal("table")
				expect(#inv.items).to.equal(0)
			end)
		end)

		describe("getEntriesOfKind", function()
			it("returns only entries whose registered kind matches", function()
				StateSyncClientStore.inventory({
					items = {
						{ itemType = "rusted-saw", quantity = 3 },
						{ itemType = "phoenix-blade", uid = "i1" },
						{ itemType = "wood", quantity = 10 },
					},
				})
				local weapons = InventoryServiceClient:getEntriesOfKind("weapon")
				expect(#weapons).to.equal(2)
				local itemTypes = {}
				for _, entry in weapons do
					itemTypes[entry.itemType] = true
				end
				expect(itemTypes["rusted-saw"]).to.equal(true)
				expect(itemTypes["phoenix-blade"]).to.equal(true)
				expect(itemTypes["wood"]).to.equal(nil)
			end)

			it("returns an empty table before the first sync", function()
				StateSyncClientStore.inventory({ items = {} })
				local entries = InventoryServiceClient:getEntriesOfKind("weapon")
				expect(type(entries)).to.equal("table")
				expect(#entries).to.equal(0)
			end)
		end)

		describe("getAffixes / displayName", function()
			it("getAffixes passes through the entry's affixes", function()
				local entry = { itemType = "rusted-saw", uid = "1_1", affixes = { warriors = 3 } }
				expect(InventoryServiceClient:getAffixes(entry).warriors).to.equal(3)
			end)

			it("displayName prefixes the definition name with the affix display name", function()
				local entry = { itemType = "rusted-saw", uid = "1_1", affixes = { warriors = 3 } }
				expect(InventoryServiceClient:displayName(entry)).to.equal("Titan's Rusted Saw Blade")
			end)

			it("displayName returns the plain definition name when there is no affix", function()
				local entry = { itemType = "rusted-saw", uid = "1_1" }
				expect(InventoryServiceClient:displayName(entry)).to.equal("Rusted Saw Blade")
			end)
		end)

		describe("getState", function()
			it("reports a count/cap string per registered kind", function()
				StateSyncClientStore.inventory({
					items = {
						{ itemType = "rusted-saw", quantity = 3 }, -- weapon (unique-kind, but stored loosely here for the count)
						{ itemType = "phoenix-blade", uid = "i1" }, -- weapon
						{ itemType = "wood", quantity = 10 }, -- misc
					},
				})
				local state = InventoryServiceClient:getState()
				local entriesPerKind = state.entriesPerKind :: { [string]: string }
				expect(entriesPerKind.weapon).to.equal(`2/{ItemConstants.KIND_CAPS.weapon}`)
				expect(entriesPerKind.misc).to.equal(`1/{ItemConstants.KIND_CAPS.misc}`)
				expect(entriesPerKind.armour).to.equal(`0/{ItemConstants.KIND_CAPS.armour}`)
				expect(entriesPerKind.consumable).to.equal(`0/{ItemConstants.KIND_CAPS.consumable}`)
			end)

			it("reports every kind at 0 before the first sync", function()
				StateSyncClientStore.inventory({ items = {} })
				local state = InventoryServiceClient:getState()
				local entriesPerKind = state.entriesPerKind :: { [string]: string }
				for _, kind in ItemConstants.KINDS do
					expect(entriesPerKind[kind]).to.equal(`0/{ItemConstants.KIND_CAPS[kind]}`)
				end
			end)
		end)
	end)
end
