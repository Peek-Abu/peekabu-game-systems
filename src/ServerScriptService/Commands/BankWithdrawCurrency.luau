--!strict
return {
	Name = "bankwithdrawcurrency",
	Aliases = {},
	Description = "Moves currency out of a player's bank into their active balance.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player" },
		{ Type = "currencyType", Name = "currencyType", Description = "The currency type (e.g. jaku)" },
		{ Type = "number", Name = "amount", Description = "The amount to withdraw" },
	},
}
