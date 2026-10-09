--!strict
return {
	Name = "marketplacepremiumadd",
	Aliases = { "premiumadd" },
	Description = "Adds premium currency to a player's account.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to give premium to" },
		{ Type = "integer", Name = "amount", Description = "A positive whole amount" },
	},
}
