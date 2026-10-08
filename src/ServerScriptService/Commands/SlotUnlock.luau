--!strict
return {
	Name = "slotunlock",
	Description = "Grants a character slot to a player (stands in for the dev-product grant).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to grant a slot to" },
		{ Type = "integer", Name = "slot", Description = "The slot to unlock (1-3)" },
	},
}
