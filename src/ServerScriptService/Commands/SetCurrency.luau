--!strict
return {
	Name = "SetCurrency",
	Aliases = {"setmoney"},
	Description = "Sets a player's currency to a specific amount.",
	Group = "Admins",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "The player to set currency for",
		},
		{
			Type = "string",
			Name = "currencyType",
			Description = "The type of currency (gold, gems, etc.)",
		},
		{
			Type = "number",
			Name = "amount",
			Description = "The amount to set",
		}
	}
}
