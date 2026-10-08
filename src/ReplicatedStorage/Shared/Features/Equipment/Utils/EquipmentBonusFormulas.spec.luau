--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentBonusFormulas = require(ReplicatedStorage.Shared.Features.Equipment.Utils.EquipmentBonusFormulas)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

local function unique(itemType: string, uid: string): PlayerDataTypes.UniqueEntry
	return { itemType = itemType, uid = uid }
end

return function()
	describe("EquipmentBonusFormulas", function()
		beforeAll(function()
			-- Idempotent: ItemContentRegistry.init() no-ops if already seeded in this VM.
			ItemContentRegistry.init()
		end)

		it("returns {} for nil equipment", function()
			local bonuses = EquipmentBonusFormulas.aggregate(nil)
			expect(next(bonuses)).to.equal(nil)
		end)

		it("returns {} when nothing is equipped", function()
			local bonuses = EquipmentBonusFormulas.aggregate({ slots = {} })
			expect(next(bonuses)).to.equal(nil)
		end)

		it("sums an equipped item's statBonuses", function()
			local bonuses = EquipmentBonusFormulas.aggregate({ slots = { helmet = unique("chambered-helmet", "h1") } })
			expect(bonuses.rotEndurance).to.equal(8)
		end)

		it("sums bonuses across multiple equipped items", function()
			-- rusted-saw has no statBonuses (a weapon fixture with none declared); chambered-helmet
			-- does — proves an item with no bonuses is tolerated alongside one that has them.
			local bonuses = EquipmentBonusFormulas.aggregate({
				slots = {
					weapon = unique("rusted-saw", "w1"),
					helmet = unique("chambered-helmet", "h1"),
				},
			})
			expect(bonuses.rotEndurance).to.equal(8)
		end)

		it("ignores an entry whose itemType has no registered ItemDefinition", function()
			expect(ItemRegistry.get("not-a-real-item")).to.equal(nil) -- sanity: truly unregistered
			local bonuses = EquipmentBonusFormulas.aggregate({ slots = { helmet = unique("not-a-real-item", "x1") } })
			expect(next(bonuses)).to.equal(nil)
		end)

		it("folds a rolled affix on top of the definition's statBonuses (both to the same stat sum)", function()
			-- warriors → +strength; rusted-saw has no statBonuses, so this isolates the affix fold.
			local weapon = unique("rusted-saw", "w1")
			weapon.affixes = { warriors = 3 }
			local bonuses = EquipmentBonusFormulas.aggregate({ slots = { weapon = weapon } })
			expect(bonuses.strength).to.equal(3)
		end)

		it("sums a fixed statBonus and a rolled affix that target the same stat id", function()
			-- Give chambered-helmet an armour affix on rotEndurance (its statBonuses stat) → they add.
			local helmet = unique("chambered-helmet", "h1")
			helmet.affixes = { warded = 2 } -- warded → +rotEndurance
			local bonuses = EquipmentBonusFormulas.aggregate({ slots = { helmet = helmet } })
			expect(bonuses.rotEndurance).to.equal(8 + 2)
		end)

		it("skips a retired affixId without erroring and contributes nothing for it", function()
			local weapon = unique("rusted-saw", "w1")
			weapon.affixes = { ["retired-affix"] = 5 }
			local bonuses = EquipmentBonusFormulas.aggregate({ slots = { weapon = weapon } })
			expect(next(bonuses)).to.equal(nil)
		end)

		it("folds a reserved-Tier-1 statRolls map (proves the base-stat path before combat)", function()
			local weapon = unique("rusted-saw", "w1")
			weapon.statRolls = { strength = 4 }
			local bonuses = EquipmentBonusFormulas.aggregate({ slots = { weapon = weapon } })
			expect(bonuses.strength).to.equal(4)
		end)
	end)
end
