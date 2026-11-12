--!strict
return {
	Name = "trainingreset",
	Aliases = { "training-reset" },
	Description = "Makes a player new to training again, tips included (you, when no player is named).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player (default: you)", Optional = true },
	},
}
