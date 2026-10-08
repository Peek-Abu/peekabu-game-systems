--!strict
return {
	Name = "statrespec",
	Aliases = { "respec" },
	Description = "Refunds all invested stat points back into unspent pools.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to respec" },
	},
}
