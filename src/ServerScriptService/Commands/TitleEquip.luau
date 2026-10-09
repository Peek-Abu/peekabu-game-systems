--!strict
return {
	Name = "titleequip",
	Aliases = {},
	Description = "Equips one of a player's earned titles on their active character.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to equip the title for" },
		{ Type = "titleId", Name = "title", Description = "A registered title id the player has earned" },
	},
}
