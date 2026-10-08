--!strict
--[=[
	EquipmentConstants: the ONE declaration site for the equip-slot registry — which slot ids exist
	and which item kind each accepts.

	Adding a slot is an edit here — never a schema change. The slice validator (Task 3) rejects an
	unknown slot id against this registry, same rule as ItemConstants/StatConstants.

	@class EquipmentConstants
]=]

-- Dynamic registry key — same documented rationale as ItemConstants.ItemKind.
export type EquipSlotId = string

--[=[
	One equip slot's shape.
	@interface SlotDefinition
	.acceptsKind string -- The ItemConstants kind this slot accepts (e.g. "weapon", "armour")
]=]
export type SlotDefinition = {
	acceptsKind: string,
}

-- The five starting slots, matching the real live game's armour granularity: one weapon slot, plus
-- helmet/pauldrons/chestplate/greaves for armour.
local SLOTS: { [string]: SlotDefinition } = {
	weapon = { acceptsKind = "weapon" },
	helmet = { acceptsKind = "armour" },
	pauldrons = { acceptsKind = "armour" },
	chestplate = { acceptsKind = "armour" },
	greaves = { acceptsKind = "armour" },
}

local EquipmentConstants = {
	SLOTS = SLOTS,
}

--[=[
	True if `slotId` names a registered equip slot.
	@param slotId string -- A candidate slot id
	@return boolean
]=]
function EquipmentConstants.isValidSlot(slotId: string): boolean
	return EquipmentConstants.SLOTS[slotId] ~= nil
end

return EquipmentConstants
