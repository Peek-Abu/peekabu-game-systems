--!strict
local EquipmentConstants = require(script.Parent.EquipmentConstants)

return function()
	describe("SLOTS", function()
		it("has the five starting slots, each accepting a valid kind", function()
			local expectedSlots = { "weapon", "helmet", "pauldrons", "chestplate", "greaves" }
			for _, slotId in expectedSlots do
				expect(EquipmentConstants.SLOTS[slotId]).to.be.ok()
			end
		end)

		it("assigns weapon to the weapon kind and the rest to armour", function()
			expect(EquipmentConstants.SLOTS.weapon.acceptsKind).to.equal("weapon")
			expect(EquipmentConstants.SLOTS.helmet.acceptsKind).to.equal("armour")
			expect(EquipmentConstants.SLOTS.pauldrons.acceptsKind).to.equal("armour")
			expect(EquipmentConstants.SLOTS.chestplate.acceptsKind).to.equal("armour")
			expect(EquipmentConstants.SLOTS.greaves.acceptsKind).to.equal("armour")
		end)
	end)

	describe("isValidSlot", function()
		it("accepts every registered slot id", function()
			for slotId in EquipmentConstants.SLOTS do
				expect(EquipmentConstants.isValidSlot(slotId)).to.equal(true)
			end
		end)

		it("rejects an unknown slot id", function()
			expect(EquipmentConstants.isValidSlot("trinket")).to.equal(false)
		end)
	end)
end
