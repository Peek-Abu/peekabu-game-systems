--!strict
return {
	Name = "cosmeticequip",
	Aliases = {},
	Description = "Changes what a player wears: employee, skin, idle, emote or sticker (blocked during a shift).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player" },
		{ Type = "string", Name = "kind", Description = "employee | skin | idle | emote | sticker" },
		{ Type = "string", Name = "id", Description = 'The item id ("-" clears an emote or sticker slot)' },
		{
			Type = "number",
			Name = "number",
			Description = "Style for a skin, slot for an emote or sticker",
			Optional = true,
		},
		{
			Type = "string",
			Name = "employee",
			Description = "For an idle or emote (default: their current employee)",
			Optional = true,
		},
	},
}
