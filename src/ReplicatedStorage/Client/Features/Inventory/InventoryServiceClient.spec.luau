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
				StateSyncClientStore.inventory({ items = { { itemType = "wrench", uid = "i0" } } })
				local inv = InventoryServiceClient:getInventory()
				expect(#inv.items).to.equal(1)
				expect(inv.items[1].itemType).to.equal("wrench")
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
						{ itemType = "wrench", uid = "i0" },
						{ itemType = "golden-wrench", uid = "i1" },
						{ itemType = "scrap", quantity = 10 },
					},
				})
				local tools = InventoryServiceClient:getEntriesOfKind("tool")
				expect(#tools).to.equal(2)
				local itemTypes = {}
				for _, entry in tools do
					itemTypes[entry.itemType] = true
				end
				expect(itemTypes["wrench"]).to.equal(true)
				expect(itemTypes["golden-wrench"]).to.equal(true)
				expect(itemTypes["scrap"]).to.equal(nil)
			end)

			it("returns an empty table before the first sync", function()
				StateSyncClientStore.inventory({ items = {} })
				local entries = InventoryServiceClient:getEntriesOfKind("tool")
				expect(type(entries)).to.equal("table")
				expect(#entries).to.equal(0)
			end)
		end)

		describe("getAttrs / displayName", function()
			it("getAttrs passes through the entry's attrs", function()
				local entry = { itemType = "wrench", uid = "1_1", attrs = { level = 3, nickname = "Old Faithful" } }
				local attrs = InventoryServiceClient:getAttrs(entry)
				expect(attrs).to.equal(entry.attrs)
				expect(attrs.level).to.equal(3)
				expect(attrs.nickname).to.equal("Old Faithful")
			end)

			it("getAttrs returns nil for an entry with no attrs", function()
				local entry = { itemType = "wrench", uid = "1_1" }
				expect(InventoryServiceClient:getAttrs(entry)).to.equal(nil)
			end)

			it("displayName returns the plain definition name, ignoring attrs", function()
				local entry = { itemType = "wrench", uid = "1_1", attrs = { level = 3 } }
				expect(InventoryServiceClient:displayName(entry)).to.equal("Wrench")
			end)

			it("displayName returns the definition name for an entry with no attrs", function()
				local entry = { itemType = "golden-wrench", uid = "1_2" }
				expect(InventoryServiceClient:displayName(entry)).to.equal("Golden Wrench")
			end)

			it("displayName falls back to the raw itemType when the definition is unknown", function()
				local entry = { itemType = "retired-item", uid = "1_3" }
				expect(InventoryServiceClient:displayName(entry)).to.equal("retired-item")
			end)
		end)

		describe("getState", function()
			it("reports a count/cap string per registered kind", function()
				StateSyncClientStore.inventory({
					items = {
						{ itemType = "wrench", uid = "i0" }, -- tool
						{ itemType = "golden-wrench", uid = "i1" }, -- tool
						{ itemType = "scrap", quantity = 10 }, -- misc
					},
				})
				local state = InventoryServiceClient:getState()
				local entriesPerKind = state.entriesPerKind :: { [string]: string }
				expect(entriesPerKind.tool).to.equal(`2/{ItemConstants.KIND_CAPS.tool}`)
				expect(entriesPerKind.misc).to.equal(`1/{ItemConstants.KIND_CAPS.misc}`)
				expect(entriesPerKind.wearable).to.equal(`0/{ItemConstants.KIND_CAPS.wearable}`)
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
