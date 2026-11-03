--!strict
return {
	Name = "abilityreset",
	Aliases = { "ability-reset" },
	Description = "Makes a player's employee ability ready right now (you, when no player is named).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player (default: you)", Optional = true },
	},
}
