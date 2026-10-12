--!strict
-- Shared equipment policy; the server supplies its own crew/equip/carry/alive facts.
local VacuumEquipmentRules = {}
function VacuumEquipmentRules.canVacuum(active: boolean, equipped: boolean, carrying: boolean, alive: boolean): boolean
	return active and equipped and not carrying and alive
end
function VacuumEquipmentRules.shouldEquip(
	first: boolean,
	wasCarrying: boolean,
	carrying: boolean,
	resume: boolean
): boolean
	return not carrying and (first or (wasCarrying and resume))
end
return table.freeze(VacuumEquipmentRules)
