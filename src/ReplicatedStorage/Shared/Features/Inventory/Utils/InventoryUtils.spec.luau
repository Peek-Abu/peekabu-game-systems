--!strict
--[=[
	Unit tests for InventoryUtils module.
	Covers the { items: { InventoryEntry } } (StackEntry | UniqueEntry) query surface: countOf,
	findByUid, entriesOfKind, countEntriesOfKind, hasItem.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryUtils = require(script.Parent.InventoryUtils)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)

return function()
	beforeEach(function()
		-- Idempotent: ItemContentRegistry.init() no-ops if already seeded in this VM.
		ItemContentRegistry.init()
	end)

	-- Fixture: a mix of stackable (healing-tonic, wood: misc/consumable) and unique (rusted-saw,
	-- phoenix-blade: weapons) entries, including TWO separate stacks of the same itemType (wood)
	-- so countOf's "stacks summed" behavior is actually exercised, and two unique instances of the
	-- same itemType (rusted-saw) so instance-count semantics are exercised too.
	local function makeInventory(): PlayerDataTypes.Inventory
		return {
			items = {
				{ itemType = "healing-tonic", quantity = 4 } :: PlayerDataTypes.StackEntry,
				{ itemType = "wood", quantity = 10 } :: PlayerDataTypes.StackEntry,
				{ itemType = "wood", quantity = 5 } :: PlayerDataTypes.StackEntry,
				{ itemType = "rusted-saw", uid = "u1_1" } :: PlayerDataTypes.UniqueEntry,
				{ itemType = "rusted-saw", uid = "u1_2" } :: PlayerDataTypes.UniqueEntry,
				{ itemType = "phoenix-blade", uid = "u1_3" } :: PlayerDataTypes.UniqueEntry,
				{ itemType = "chambered-helmet", uid = "u1_4" } :: PlayerDataTypes.UniqueEntry,
			},
		}
	end

	describe("countOf", function()
		it("sums quantity across multiple stacks of the same itemType", function()
			local inventory = makeInventory()
			expect(InventoryUtils.countOf(inventory, "wood")).to.equal(15)
		end)

		it("returns a single stack's quantity", function()
			local inventory = makeInventory()
			expect(InventoryUtils.countOf(inventory, "healing-tonic")).to.equal(4)
		end)

		it("counts unique instances rather than summing a quantity field", function()
			local inventory = makeInventory()
			expect(InventoryUtils.countOf(inventory, "rusted-saw")).to.equal(2)
		end)

		it("returns 0 for an itemType not present", function()
			local inventory = makeInventory()
			expect(InventoryUtils.countOf(inventory, "crypt-key")).to.equal(0)
		end)
	end)

	describe("findByUid", function()
		it("finds a unique entry by uid and returns its index", function()
			local inventory = makeInventory()
			local index, entry = InventoryUtils.findByUid(inventory, "u1_3")
			expect(index).to.equal(6)
			expect(entry).to.be.ok()
			expect((entry :: PlayerDataTypes.UniqueEntry).itemType).to.equal("phoenix-blade")
		end)

		it("returns nil, nil for a uid that doesn't exist", function()
			local inventory = makeInventory()
			local index, entry = InventoryUtils.findByUid(inventory, "no-such-uid")
			expect(index).to.equal(nil)
			expect(entry).to.equal(nil)
		end)

		it("returns nil, nil on an empty inventory", function()
			local inventory: PlayerDataTypes.Inventory = { items = {} }
			local index, entry = InventoryUtils.findByUid(inventory, "u1_1")
			expect(index).to.equal(nil)
			expect(entry).to.equal(nil)
		end)
	end)

	describe("entriesOfKind", function()
		it("filters to entries whose itemType's definition kind matches, via ItemRegistry.kindOf", function()
			local inventory = makeInventory()
			local weapons = InventoryUtils.entriesOfKind(inventory, "weapon")
			expect(#weapons).to.equal(3) -- rusted-saw x2, phoenix-blade x1

			local misc = InventoryUtils.entriesOfKind(inventory, "misc")
			expect(#misc).to.equal(2) -- wood x2 (two stacks)

			local consumable = InventoryUtils.entriesOfKind(inventory, "consumable")
			expect(#consumable).to.equal(1) -- healing-tonic

			local armour = InventoryUtils.entriesOfKind(inventory, "armour")
			expect(#armour).to.equal(1) -- chambered-helmet
		end)

		it("returns an empty array for a kind with no matching entries", function()
			local inventory: PlayerDataTypes.Inventory = { items = {} }
			expect(#InventoryUtils.entriesOfKind(inventory, "weapon")).to.equal(0)
		end)
	end)

	describe("countEntriesOfKind", function()
		it("counts entries (not summed quantity) of a kind", function()
			local inventory = makeInventory()
			-- Two SEPARATE wood stacks -> 2 entries, even though countOf sums their quantity to 15.
			expect(InventoryUtils.countEntriesOfKind(inventory, "misc")).to.equal(2)
			expect(InventoryUtils.countEntriesOfKind(inventory, "weapon")).to.equal(3)
		end)

		it("returns 0 for a kind with no entries", function()
			local inventory: PlayerDataTypes.Inventory = { items = {} }
			expect(InventoryUtils.countEntriesOfKind(inventory, "armour")).to.equal(0)
		end)
	end)

	describe("hasItem", function()
		it("defaults to requiring at least 1 when quantity is omitted", function()
			local inventory = makeInventory()
			expect(InventoryUtils.hasItem(inventory, "healing-tonic")).to.equal(true)
			expect(InventoryUtils.hasItem(inventory, "crypt-key")).to.equal(false)
		end)

		it("checks a stackable's total summed quantity against the requested amount", function()
			local inventory = makeInventory()
			expect(InventoryUtils.hasItem(inventory, "wood", 15)).to.equal(true)
			expect(InventoryUtils.hasItem(inventory, "wood", 16)).to.equal(false)
		end)

		it("checks a unique itemType's instance count against the requested amount", function()
			local inventory = makeInventory()
			-- Two rusted-saw instances exist.
			expect(InventoryUtils.hasItem(inventory, "rusted-saw", 2)).to.equal(true)
			expect(InventoryUtils.hasItem(inventory, "rusted-saw", 3)).to.equal(false)
			-- A single phoenix-blade instance satisfies a request of 1 but not 2.
			expect(InventoryUtils.hasItem(inventory, "phoenix-blade", 1)).to.equal(true)
			expect(InventoryUtils.hasItem(inventory, "phoenix-blade", 2)).to.equal(false)
		end)

		it("returns false for an itemType not present at all", function()
			local inventory = makeInventory()
			expect(InventoryUtils.hasItem(inventory, "crypt-key", 1)).to.equal(false)
		end)
	end)

	describe("validateModifierMap", function()
		it("accepts a nil map (the field is simply absent)", function()
			local ok = InventoryUtils.validateModifierMap(nil)
			expect(ok).to.equal(true)
		end)

		it("accepts a well-formed modifier map", function()
			local ok = InventoryUtils.validateModifierMap({ warriors = 3 })
			expect(ok).to.equal(true)
		end)

		it("tolerates a retired / unknown key (config-drift, not corruption)", function()
			local ok = InventoryUtils.validateModifierMap({ ["retired-affix"] = 2 })
			expect(ok).to.equal(true)
		end)

		it("rejects a non-number value", function()
			local ok, reason = InventoryUtils.validateModifierMap({ warriors = "big" :: any })
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)

		it("rejects a NaN value", function()
			local ok = InventoryUtils.validateModifierMap({ warriors = 0 / 0 })
			expect(ok).to.equal(false)
		end)

		it("rejects a non-string key (malformed/corrupt data)", function()
			-- A numeric key would later crash displayPrefix's table.sort over mixed key types.
			local ok = InventoryUtils.validateModifierMap({ [123] = 5 } :: any)
			expect(ok).to.equal(false)
		end)

		it("rejects an empty-string key", function()
			local ok = InventoryUtils.validateModifierMap({ [""] = 5 })
			expect(ok).to.equal(false)
		end)
	end)
end
