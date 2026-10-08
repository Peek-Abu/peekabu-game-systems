--!strict
return {
	Name = "titlerevoke",
	Aliases = {},
	Description = "Revokes an earned title from a player; clears it atomically if currently equipped.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to revoke the title from" },
		{ Type = "titleId", Name = "title", Description = "A registered title id" },
	},
}
