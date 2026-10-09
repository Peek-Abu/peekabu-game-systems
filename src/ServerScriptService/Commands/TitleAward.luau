--!strict
return {
	Name = "titleaward",
	Aliases = {},
	Description = "Awards a registered title to a player (idempotent).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to award the title to" },
		{ Type = "titleId", Name = "title", Description = "A registered title id" },
	},
}
