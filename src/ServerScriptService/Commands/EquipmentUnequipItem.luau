--!strict
return {
	Name = "equipmentunequipitem",
	Aliases = {},
	Description = "Unequips whatever occupies a slot, returning it to a player's inventory.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to unequip the item for" },
		{ Type = "string", Name = "slotId", Description = "The equipment slot id to clear" },
	},
}
