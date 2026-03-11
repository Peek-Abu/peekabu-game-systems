--!strict
return {
	Name = "AddCurrency",
	Aliases = {"addmoney", "givemoney"},
	Description = "Adds currency to a player's account.",
	Group = "Admins",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "The player to give currency to",
		},
		{
			Type = "string",
			Name = "currencyType",
			Description = "The type of currency (gold, gems, etc.)",
		},
		{
			Type = "number",
			Name = "amount",
			Description = "The amount to add",
		}
	}
}
