--!strict
return {
	Name = "GiveItem",
	Aliases = {"additem"},
	Description = "Gives an item to a player's inventory.",
	Group = "Admins",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "The player to give the item to",
		},
		{
			Type = "string",
			Name = "itemType",
			Description = "The type of item to give",
		},
		{
			Type = "number",
			Name = "quantity",
			Description = "The quantity to give (default 1)",
			Optional = true,
			Default = 1,
		}
	}
}
