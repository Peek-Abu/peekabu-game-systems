--!strict
--[=[
	Unit tests for ItemRegistry — the runtime item-type registry.

	The backing map is module-global and shared with other specs (the inventory specs rely on
	ItemContentRegistry.init() having registered the starter set — "wrench", "golden-wrench", etc.), so
	these tests register only uniquely-named spec items and never remove anything. Registration
	VALIDATES (kind, rarity, stackMax, maxStacks) and REJECTS double registration, so every spec item
	name used here must be unique across the whole spec suite.
]=]

local ItemRegistry = require(script.Parent.ItemRegistry)

return function()
	describe("register / get", function()
		it("registers a definition and returns it by type", function()
			ItemRegistry.register("spec-test-item", {
				name = "Spec Test Item",
				icon = "rbxassetid://0",
				rarity = "common",
				kind = "tool",
			})
			local def = ItemRegistry.get("spec-test-item")
			expect(def).to.be.ok()
			expect(def and def.name).to.equal("Spec Test Item")
		end)

		it("returns nil for an unregistered type", function()
			expect(ItemRegistry.get("spec-never-registered")).to.equal(nil)
		end)

		it("rejects double registration of the same item type", function()
			ItemRegistry.register("spec-double-item", {
				name = "First",
				rarity = "common",
				kind = "tool",
			})
			expect(function()
				ItemRegistry.register("spec-double-item", {
					name = "Second",
					rarity = "rare",
					kind = "tool",
				})
			end).to.throw()
			-- The original registration is untouched.
			local def = ItemRegistry.get("spec-double-item")
			expect(def and def.name).to.equal("First")
		end)

		it("rejects an unknown kind", function()
			expect(function()
				ItemRegistry.register("spec-bad-kind", {
					name = "Bad Kind",
					rarity = "common",
					kind = "vehicle",
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-bad-kind")).to.equal(nil)
		end)

		it("rejects an unknown rarity", function()
			expect(function()
				ItemRegistry.register("spec-bad-rarity", {
					name = "Bad Rarity",
					rarity = "mythic",
					kind = "tool",
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-bad-rarity")).to.equal(nil)
		end)

		it("accepts a consumable without a stackMax (a unique consumable)", function()
			ItemRegistry.register("spec-unique-consumable", {
				name = "Unique Consumable",
				rarity = "common",
				kind = "consumable",
			})
			expect(ItemRegistry.get("spec-unique-consumable")).to.be.ok()
		end)

		it("rejects a non-positive or non-integer stackMax", function()
			expect(function()
				ItemRegistry.register("spec-consumable-zero-stack", {
					name = "Zero Stack",
					rarity = "common",
					kind = "consumable",
					stackMax = 0,
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-consumable-zero-stack")).to.equal(nil)

			expect(function()
				ItemRegistry.register("spec-consumable-negative-stack", {
					name = "Negative Stack",
					rarity = "common",
					kind = "consumable",
					stackMax = -3,
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-consumable-negative-stack")).to.equal(nil)

			expect(function()
				ItemRegistry.register("spec-consumable-fractional-stack", {
					name = "Fractional Stack",
					rarity = "common",
					kind = "consumable",
					stackMax = 1.5,
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-consumable-fractional-stack")).to.equal(nil)
		end)

		it("rejects a non-positive or non-integer maxStacks when declared", function()
			expect(function()
				ItemRegistry.register("spec-consumable-bad-maxstacks", {
					name = "Bad Max Stacks",
					rarity = "common",
					kind = "consumable",
					stackMax = 5,
					maxStacks = 0,
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-consumable-bad-maxstacks")).to.equal(nil)

			expect(function()
				ItemRegistry.register("spec-consumable-fractional-maxstacks", {
					name = "Fractional Max Stacks",
					rarity = "common",
					kind = "consumable",
					stackMax = 5,
					maxStacks = 2.5,
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-consumable-fractional-maxstacks")).to.equal(nil)
		end)

		it("rejects maxStacks without a stackMax (a unique item has no stacks)", function()
			expect(function()
				ItemRegistry.register("spec-maxstacks-without-stackmax", {
					name = "Max Stacks Without Stack Max",
					rarity = "common",
					kind = "misc",
					maxStacks = 1,
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-maxstacks-without-stackmax")).to.equal(nil)
		end)

		it("accepts a well-formed stackable consumable", function()
			ItemRegistry.register("spec-good-consumable", {
				name = "Good Consumable",
				rarity = "common",
				kind = "consumable",
				stackMax = 10,
				maxStacks = 1,
			})
			expect(ItemRegistry.get("spec-good-consumable")).to.be.ok()
		end)

		it("accepts a misc item without a stackMax (non-stackable)", function()
			ItemRegistry.register("spec-nonstackable-misc", {
				name = "Nonstackable Misc",
				rarity = "legendary",
				kind = "misc",
			})
			expect(ItemRegistry.get("spec-nonstackable-misc")).to.be.ok()
		end)
	end)

	describe("isValidItemType", function()
		it("is true for a registered type and false otherwise", function()
			ItemRegistry.register("spec-valid-item", {
				name = "Valid",
				rarity = "common",
				kind = "tool",
			})
			expect(ItemRegistry.isValidItemType("spec-valid-item")).to.equal(true)
			expect(ItemRegistry.isValidItemType("spec-never-registered")).to.equal(false)
		end)
	end)

	describe("getValidItemTypes", function()
		it("includes every registered type", function()
			ItemRegistry.register("spec-enum-item", {
				name = "Enum Item",
				rarity = "common",
				kind = "tool",
			})
			local seen: { [string]: boolean } = {}
			for _, itemType in ItemRegistry.getValidItemTypes() do
				seen[itemType] = true
			end
			expect(seen["spec-enum-item"]).to.equal(true)
		end)
	end)

	describe("kindOf", function()
		it("returns the registered kind for a known item type", function()
			ItemRegistry.register("spec-kindof-tool", {
				name = "Kindof Tool",
				rarity = "common",
				kind = "tool",
			})
			expect(ItemRegistry.kindOf("spec-kindof-tool")).to.equal("tool")
		end)

		it("returns nil for an unknown item type", function()
			expect(ItemRegistry.kindOf("spec-never-registered")).to.equal(nil)
		end)
	end)

	describe("isStackable", function()
		it("is true for a consumable that declares a stackMax", function()
			ItemRegistry.register("spec-stackable-consumable", {
				name = "Stackable Consumable",
				rarity = "common",
				kind = "consumable",
				stackMax = 5,
			})
			expect(ItemRegistry.isStackable("spec-stackable-consumable")).to.equal(true)
		end)

		it("is false for a consumable without a stackMax", function()
			ItemRegistry.register("spec-unstackable-consumable", {
				name = "Unstackable Consumable",
				rarity = "common",
				kind = "consumable",
			})
			expect(ItemRegistry.isStackable("spec-unstackable-consumable")).to.equal(false)
		end)

		it("is true for a tool that declares a stackMax (stackability is declared, not by kind)", function()
			ItemRegistry.register("spec-stackable-tool", {
				name = "Stackable Tool",
				rarity = "common",
				kind = "tool",
				stackMax = 3,
			})
			expect(ItemRegistry.isStackable("spec-stackable-tool")).to.equal(true)
		end)

		it("is false for a tool without a stackMax", function()
			ItemRegistry.register("spec-unstackable-tool", {
				name = "Unstackable Tool",
				rarity = "common",
				kind = "tool",
			})
			expect(ItemRegistry.isStackable("spec-unstackable-tool")).to.equal(false)
		end)

		it("is true for a misc item that declares a stackMax", function()
			ItemRegistry.register("spec-stackable-misc", {
				name = "Stackable Misc",
				rarity = "common",
				kind = "misc",
				stackMax = 30,
			})
			expect(ItemRegistry.isStackable("spec-stackable-misc")).to.equal(true)
		end)

		it("is false for a misc item without a stackMax", function()
			ItemRegistry.register("spec-unstackable-misc", {
				name = "Unstackable Misc",
				rarity = "legendary",
				kind = "misc",
			})
			expect(ItemRegistry.isStackable("spec-unstackable-misc")).to.equal(false)
		end)

		it("is false for a wearable without a stackMax", function()
			ItemRegistry.register("spec-unstackable-wearable", {
				name = "Unstackable Wearable",
				rarity = "common",
				kind = "wearable",
			})
			expect(ItemRegistry.isStackable("spec-unstackable-wearable")).to.equal(false)
		end)

		it("is false for an unregistered item type", function()
			expect(ItemRegistry.isStackable("spec-never-registered")).to.equal(false)
		end)
	end)
end
