--!strict
--[=[
	Unit tests for InventoryUtils module.
	Covers the { items: { InventoryEntry } } (StackEntry | UniqueEntry) query surface: countOf,
	findByUid, entriesOfKind, countEntriesOfKind, hasItem, validateAttrs.
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

	-- Fixture: a mix of stackable (medkit: consumable, scrap: misc) and unique (wrench,
	-- golden-wrench: tools; hard-hat: wearable) entries, including TWO separate stacks of the same itemType (scrap)
	-- so countOf's "stacks summed" behavior is actually exercised, and two unique instances of the
	-- same itemType (wrench) so instance-count semantics are exercised too.
	local function makeInventory(): PlayerDataTypes.Inventory
		return {
			items = {
				{ itemType = "medkit", quantity = 4 } :: PlayerDataTypes.StackEntry,
				{ itemType = "scrap", quantity = 10 } :: PlayerDataTypes.StackEntry,
				{ itemType = "scrap", quantity = 5 } :: PlayerDataTypes.StackEntry,
				{ itemType = "wrench", uid = "u1_1" } :: PlayerDataTypes.UniqueEntry,
				{ itemType = "wrench", uid = "u1_2" } :: PlayerDataTypes.UniqueEntry,
				{ itemType = "golden-wrench", uid = "u1_3" } :: PlayerDataTypes.UniqueEntry,
				{ itemType = "hard-hat", uid = "u1_4" } :: PlayerDataTypes.UniqueEntry,
			},
		}
	end

	describe("countOf", function()
		it("sums quantity across multiple stacks of the same itemType", function()
			local inventory = makeInventory()
			expect(InventoryUtils.countOf(inventory, "scrap")).to.equal(15)
		end)

		it("returns a single stack's quantity", function()
			local inventory = makeInventory()
			expect(InventoryUtils.countOf(inventory, "medkit")).to.equal(4)
		end)

		it("counts unique instances rather than summing a quantity field", function()
			local inventory = makeInventory()
			expect(InventoryUtils.countOf(inventory, "wrench")).to.equal(2)
		end)

		it("returns 0 for an itemType not present", function()
			local inventory = makeInventory()
			expect(InventoryUtils.countOf(inventory, "master-key")).to.equal(0)
		end)
	end)

	describe("findByUid", function()
		it("finds a unique entry by uid and returns its index", function()
			local inventory = makeInventory()
			local index, entry = InventoryUtils.findByUid(inventory, "u1_3")
			expect(index).to.equal(6)
			expect(entry).to.be.ok()
			expect((entry :: PlayerDataTypes.UniqueEntry).itemType).to.equal("golden-wrench")
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
			local tools = InventoryUtils.entriesOfKind(inventory, "tool")
			expect(#tools).to.equal(3) -- wrench x2, golden-wrench x1

			local misc = InventoryUtils.entriesOfKind(inventory, "misc")
			expect(#misc).to.equal(2) -- scrap x2 (two stacks)

			local consumable = InventoryUtils.entriesOfKind(inventory, "consumable")
			expect(#consumable).to.equal(1) -- medkit

			local wearables = InventoryUtils.entriesOfKind(inventory, "wearable")
			expect(#wearables).to.equal(1) -- hard-hat
		end)

		it("returns an empty array for a kind with no matching entries", function()
			local inventory: PlayerDataTypes.Inventory = { items = {} }
			expect(#InventoryUtils.entriesOfKind(inventory, "tool")).to.equal(0)
		end)
	end)

	describe("countEntriesOfKind", function()
		it("counts entries (not summed quantity) of a kind", function()
			local inventory = makeInventory()
			-- Two SEPARATE scrap stacks -> 2 entries, even though countOf sums their quantity to 15.
			expect(InventoryUtils.countEntriesOfKind(inventory, "misc")).to.equal(2)
			expect(InventoryUtils.countEntriesOfKind(inventory, "tool")).to.equal(3)
		end)

		it("returns 0 for a kind with no entries", function()
			local inventory: PlayerDataTypes.Inventory = { items = {} }
			expect(InventoryUtils.countEntriesOfKind(inventory, "wearable")).to.equal(0)
		end)
	end)

	describe("hasItem", function()
		it("defaults to requiring at least 1 when quantity is omitted", function()
			local inventory = makeInventory()
			expect(InventoryUtils.hasItem(inventory, "medkit")).to.equal(true)
			expect(InventoryUtils.hasItem(inventory, "master-key")).to.equal(false)
		end)

		it("checks a stackable's total summed quantity against the requested amount", function()
			local inventory = makeInventory()
			expect(InventoryUtils.hasItem(inventory, "scrap", 15)).to.equal(true)
			expect(InventoryUtils.hasItem(inventory, "scrap", 16)).to.equal(false)
		end)

		it("checks a unique itemType's instance count against the requested amount", function()
			local inventory = makeInventory()
			-- Two wrench instances exist.
			expect(InventoryUtils.hasItem(inventory, "wrench", 2)).to.equal(true)
			expect(InventoryUtils.hasItem(inventory, "wrench", 3)).to.equal(false)
			-- A single golden-wrench instance satisfies a request of 1 but not 2.
			expect(InventoryUtils.hasItem(inventory, "golden-wrench", 1)).to.equal(true)
			expect(InventoryUtils.hasItem(inventory, "golden-wrench", 2)).to.equal(false)
		end)

		it("returns false for an itemType not present at all", function()
			local inventory = makeInventory()
			expect(InventoryUtils.hasItem(inventory, "master-key", 1)).to.equal(false)
		end)
	end)

	describe("validateAttrs", function()
		it("accepts a nil map (the field is simply absent)", function()
			local ok = InventoryUtils.validateAttrs(nil)
			expect(ok).to.equal(true)
		end)

		it("accepts a well-formed map of number and string values", function()
			local ok = InventoryUtils.validateAttrs({ level = 3, nickname = "Old Faithful" })
			expect(ok).to.equal(true)
		end)

		it("accepts an empty map", function()
			local ok = InventoryUtils.validateAttrs({})
			expect(ok).to.equal(true)
		end)

		it("tolerates a retired / unknown key (config-drift, not corruption)", function()
			local ok = InventoryUtils.validateAttrs({ ["retired-attr"] = 2 })
			expect(ok).to.equal(true)
		end)

		it("accepts a string value of exactly 64 characters", function()
			local ok = InventoryUtils.validateAttrs({ nickname = string.rep("a", 64) })
			expect(ok).to.equal(true)
		end)

		it("rejects a string value longer than 64 characters", function()
			local ok, reason = InventoryUtils.validateAttrs({ nickname = string.rep("a", 65) })
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)

		it("rejects a value that is neither a number nor a string", function()
			local ok, reason = InventoryUtils.validateAttrs({ level = true :: any })
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)

		it("rejects a NaN value", function()
			local ok = InventoryUtils.validateAttrs({ level = 0 / 0 })
			expect(ok).to.equal(false)
		end)

		it("rejects an infinite value", function()
			expect((InventoryUtils.validateAttrs({ level = math.huge }))).to.equal(false)
			expect((InventoryUtils.validateAttrs({ level = -math.huge }))).to.equal(false)
		end)

		it("rejects a non-table map", function()
			local ok, reason = InventoryUtils.validateAttrs("level" :: any)
			expect(ok).to.equal(false)
			expect(reason).to.be.ok()
		end)

		it("rejects a non-string key (malformed/corrupt data)", function()
			-- A numeric key would crash any consumer that sorts or formats keys.
			local ok = InventoryUtils.validateAttrs({ [123] = 5 } :: any)
			expect(ok).to.equal(false)
		end)

		it("rejects an empty-string key", function()
			local ok = InventoryUtils.validateAttrs({ [""] = 5 })
			expect(ok).to.equal(false)
		end)
	end)
end
