--!strict
return {
	Name = "equipmentequipitem",
	Aliases = {},
	Description = "Equips an item (by uid) from a player's inventory.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to equip the item for" },
		{ Type = "string", Name = "uid", Description = "The uid of the unique item to equip" },
	},
}
