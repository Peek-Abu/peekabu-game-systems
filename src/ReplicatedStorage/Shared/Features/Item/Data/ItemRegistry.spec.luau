--!strict
--[=[
	Unit tests for ItemRegistry — the runtime item-type registry.

	The backing map is module-global and shared with other specs (the inventory specs rely on
	ItemContentRegistry.init() having registered the starter set — "rusted-saw", "phoenix-blade", etc.), so
	these tests register only uniquely-named spec items and never remove anything. Registration now
	VALIDATES (kind, rarity, consumable stackMax) and REJECTS double registration, so every spec item
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
				kind = "weapon",
				equipSlot = "weapon",
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
				kind = "weapon",
				equipSlot = "weapon",
			})
			expect(function()
				ItemRegistry.register("spec-double-item", {
					name = "Second",
					rarity = "rare",
					kind = "weapon",
					equipSlot = "weapon",
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
					kind = "vehicle" :: any,
					equipSlot = "weapon",
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-bad-kind")).to.equal(nil)
		end)

		it("rejects an unknown rarity", function()
			expect(function()
				ItemRegistry.register("spec-bad-rarity", {
					name = "Bad Rarity",
					rarity = "mythic",
					kind = "weapon",
					equipSlot = "weapon",
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-bad-rarity")).to.equal(nil)
		end)

		it("rejects a consumable without a stackMax", function()
			expect(function()
				ItemRegistry.register("spec-bad-consumable", {
					name = "Bad Consumable",
					rarity = "common",
					kind = "consumable",
					stackMax = nil :: any,
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-bad-consumable")).to.equal(nil)
		end)

		it("rejects a consumable with a non-positive or non-integer stackMax", function()
			expect(function()
				ItemRegistry.register("spec-consumable-zero-stack", {
					name = "Zero Stack",
					rarity = "common",
					kind = "consumable",
					stackMax = 0,
				})
			end).to.throw()

			expect(function()
				ItemRegistry.register("spec-consumable-fractional-stack", {
					name = "Fractional Stack",
					rarity = "common",
					kind = "consumable",
					stackMax = 1.5,
				})
			end).to.throw()
		end)

		it("rejects a consumable with a non-positive maxStacks when declared", function()
			expect(function()
				ItemRegistry.register("spec-consumable-bad-maxstacks", {
					name = "Bad Max Stacks",
					rarity = "common",
					kind = "consumable",
					stackMax = 5,
					maxStacks = 0,
				})
			end).to.throw()
		end)

		it("accepts a well-formed consumable", function()
			ItemRegistry.register("spec-good-consumable", {
				name = "Good Consumable",
				rarity = "common",
				kind = "consumable",
				stackMax = 10,
				maxStacks = 1,
			})
			expect(ItemRegistry.get("spec-good-consumable")).to.be.ok()
		end)

		it("rejects an unknown equipSlot on a weapon", function()
			expect(function()
				ItemRegistry.register("spec-bad-equipslot", {
					name = "Bad Equip Slot",
					rarity = "common",
					kind = "weapon",
					equipSlot = "trinket",
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-bad-equipslot")).to.equal(nil)
		end)

		it("rejects an equipSlot whose acceptsKind does not match the item's kind", function()
			expect(function()
				ItemRegistry.register("spec-mismatched-equipslot", {
					name = "Mismatched Equip Slot",
					rarity = "common",
					kind = "weapon",
					equipSlot = "helmet", -- helmet accepts "armour", not "weapon"
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-mismatched-equipslot")).to.equal(nil)
		end)

		it("rejects a non-positive or non-integer requiredLevel when declared", function()
			expect(function()
				ItemRegistry.register("spec-bad-required-level", {
					name = "Bad Required Level",
					rarity = "common",
					kind = "weapon",
					equipSlot = "weapon",
					requiredLevel = 0,
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-bad-required-level")).to.equal(nil)

			expect(function()
				ItemRegistry.register("spec-fractional-required-level", {
					name = "Fractional Required Level",
					rarity = "common",
					kind = "weapon",
					equipSlot = "weapon",
					requiredLevel = 2.5,
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-fractional-required-level")).to.equal(nil)
		end)

		it("rejects statBonuses keyed to an unknown stat id", function()
			expect(function()
				ItemRegistry.register("spec-bad-stat-bonus", {
					name = "Bad Stat Bonus",
					rarity = "common",
					kind = "armour",
					equipSlot = "helmet",
					statBonuses = { mana = 10 },
				})
			end).to.throw()
			expect(ItemRegistry.get("spec-bad-stat-bonus")).to.equal(nil)
		end)

		it("accepts a well-formed weapon with equipSlot, requiredLevel, and statBonuses", function()
			ItemRegistry.register("spec-good-weapon", {
				name = "Good Weapon",
				rarity = "rare",
				kind = "weapon",
				equipSlot = "weapon",
				requiredLevel = 5,
				statBonuses = { strength = 3 },
			})
			expect(ItemRegistry.get("spec-good-weapon")).to.be.ok()
		end)

		it("accepts a well-formed armour with equipSlot, requiredLevel, and statBonuses", function()
			ItemRegistry.register("spec-good-armour", {
				name = "Good Armour",
				rarity = "rare",
				kind = "armour",
				equipSlot = "chestplate",
				requiredLevel = 5,
				statBonuses = { health = 10 },
			})
			expect(ItemRegistry.get("spec-good-armour")).to.be.ok()
		end)

		it("accepts a negative statBonus (reserved for future cursed gear)", function()
			ItemRegistry.register("spec-cursed-weapon", {
				name = "Cursed Weapon",
				rarity = "cursed",
				kind = "weapon",
				equipSlot = "weapon",
				statBonuses = { strength = -5 },
			})
			expect(ItemRegistry.get("spec-cursed-weapon")).to.be.ok()
		end)

		it("accepts a misc item without a stackMax (non-stackable)", function()
			ItemRegistry.register("spec-nonstackable-misc", {
				name = "Nonstackable Misc",
				rarity = "cursed",
				kind = "misc",
				questItem = true,
			})
			expect(ItemRegistry.get("spec-nonstackable-misc")).to.be.ok()
		end)
	end)

	describe("isValidItemType", function()
		it("is true for a registered type and false otherwise", function()
			ItemRegistry.register("spec-valid-item", {
				name = "Valid",
				rarity = "common",
				kind = "weapon",
				equipSlot = "weapon",
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
				kind = "weapon",
				equipSlot = "weapon",
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
			ItemRegistry.register("spec-kindof-weapon", {
				name = "Kindof Weapon",
				rarity = "common",
				kind = "weapon",
				equipSlot = "weapon",
			})
			expect(ItemRegistry.kindOf("spec-kindof-weapon")).to.equal("weapon")
		end)

		it("returns nil for an unknown item type", function()
			expect(ItemRegistry.kindOf("spec-never-registered")).to.equal(nil)
		end)
	end)

	describe("isStackable", function()
		it("is true for a consumable (always carries a stackMax)", function()
			ItemRegistry.register("spec-stackable-consumable", {
				name = "Stackable Consumable",
				rarity = "common",
				kind = "consumable",
				stackMax = 5,
			})
			expect(ItemRegistry.isStackable("spec-stackable-consumable")).to.equal(true)
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
				rarity = "cursed",
				kind = "misc",
				questItem = true,
			})
			expect(ItemRegistry.isStackable("spec-unstackable-misc")).to.equal(false)
		end)

		it("is false for a weapon or armour", function()
			ItemRegistry.register("spec-unstackable-weapon", {
				name = "Unstackable Weapon",
				rarity = "common",
				kind = "weapon",
				equipSlot = "weapon",
			})
			expect(ItemRegistry.isStackable("spec-unstackable-weapon")).to.equal(false)
		end)

		it("is false for an unregistered item type", function()
			expect(ItemRegistry.isStackable("spec-never-registered")).to.equal(false)
		end)
	end)
end
