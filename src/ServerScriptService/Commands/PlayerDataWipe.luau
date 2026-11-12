--!strict
return {
	Name = "datawipe",
	Aliases = { "data-wipe" },
	Description = "Wipes a player's WHOLE save back to a new player's, then sends them out to rejoin. Cannot be undone.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player whose save is wiped" },
	},
}
