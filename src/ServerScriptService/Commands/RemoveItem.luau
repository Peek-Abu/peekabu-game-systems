--!strict
return {
	Name = "RemoveItem",
	Aliases = {"deleteitem"},
	Description = "Removes an item from a player's inventory.",
	Group = "Admins",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "The player to remove the item from",
		},
		{
			Type = "string",
			Name = "itemType",
			Description = "The type of item to remove",
		},
		{
			Type = "number",
			Name = "quantity",
			Description = "The quantity to remove (default 1)",
			Optional = true,
			Default = 1,
		}
	}
}
