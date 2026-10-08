--!strict
return {
	Name = "customizationsetsurface",
	Aliases = {},
	Description = "Restyles a clothing/backpack surface: its pattern and/or texture. Pass none for both to clear the channel.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to restyle" },
		{ Type = "surfaceChannel", Name = "channel", Description = "Which surface to restyle" },
		-- A plain string, deliberately: valid pattern ids depend on WHICH channel is being set
		-- (clothing and backpack draw from different catalogs), so a static enum would autocomplete
		-- values that are wrong for half the channels. The service validates against the real catalog.
		{
			Type = "string",
			Name = "pattern",
			Description = "Pattern id for that channel, - to keep it, none to clear it",
			Default = "-",
		},
		{
			Type = "surfaceTexture",
			Name = "texture",
			Description = "Texture id, - to keep it, none to clear it",
			Default = "-",
		},
	},
}
