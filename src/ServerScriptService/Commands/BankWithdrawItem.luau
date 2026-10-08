--!strict
return {
	Name = "bankwithdrawitem",
	Aliases = {},
	Description = "Moves an item out of a player's bank: a unique by uid, or a stackable's whole holding by itemType.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player whose bank to withdraw from" },
		{ Type = "string", Name = "item", Description = "A unique item's uid, or a stackable itemType" },
	},
}
