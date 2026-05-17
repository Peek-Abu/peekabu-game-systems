return {
	Name = "spawnnpc",
	Aliases = { "npc" },
	Description = "Spawn an NPC enemy at your position",
	Group = "Admin",
	Args = {
		{
			Type = "string",
			Name = "characterId",
			Description = "Character to spawn (e.g. GOKU, NARUTO)",
		},
		{
			Type = "integer",
			Name = "level",
			Description = "NPC level",
			Optional = true,
			Default = 50,
		},
		{
			Type = "number",
			Name = "aggroRadius",
			Description = "Aggro radius in studs",
			Optional = true,
			Default = 20,
		},
	},
}
