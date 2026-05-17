return {
	Name = "select",
	Aliases = { "pick", "choose" },
	Description = "Select a character to play as",
	Group = "DefaultAdmin",
	Args = {
		{
			Type = "string",
			Name = "characterId",
			Description = "Character to select (e.g. GOKU, NARUTO)",
		},
	},
}
