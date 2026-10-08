--!strict
return {
	Name = "statinvest",
	Aliases = { "invest" },
	Description = "Invests unspent points into a player's stat.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to invest for" },
		{ Type = "statId", Name = "statId", Description = "The stat to invest in" },
		{ Type = "integer", Name = "points", Description = "The number of points to invest" },
	},
}
