--!strict
return {
	Name = "statgivexp",
	Aliases = { "giveexp", "addxp" },
	Description = "Grants experience to a player.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to give XP to" },
		{ Type = "integer", Name = "amount", Description = "The amount of XP to grant" },
	},
}
