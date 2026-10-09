--!strict
return {
	Name = "npcclear",
	Aliases = {},
	Description = "Removes every NPC, or every NPC of one kind.",
	Group = "Admins",
	Args = {
		{ Type = "string", Name = "kind", Description = "Only this kind (optional)", Optional = true },
	},
}
