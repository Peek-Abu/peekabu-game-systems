--!strict
return {
	Name = "bankdepositcurrency",
	Aliases = {},
	Description = "Moves currency from a player's active balance into their bank.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player" },
		{ Type = "currencyType", Name = "currencyType", Description = "The currency type (e.g. jaku)" },
		{ Type = "number", Name = "amount", Description = "The amount to deposit" },
	},
}
