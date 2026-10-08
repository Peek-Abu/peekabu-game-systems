--!strict
return {
	Name = "slotswitch",
	Aliases = { "slot" },
	Description = "Switches a player to another character slot.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to switch" },
		{ Type = "integer", Name = "slot", Description = "The slot to switch to (1-3)" },
	},
}
