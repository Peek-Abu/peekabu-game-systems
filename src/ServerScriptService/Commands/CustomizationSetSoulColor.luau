--!strict
return {
	Name = "customizationsetsoulcolor",
	Aliases = {},
	Description = "Sets a player's soul colour. Give up to three hues; they combine into one multi-hue soul.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to change" },
		-- Hues, not whole ids: a multi-hue soul is COMPOSED, so enumerating combinations is impossible.
		-- The server joins whichever are supplied, in the order given (order changes the gradient).
		{ Type = "soulHue", Name = "hue1", Description = "First hue" },
		{ Type = "soulHue", Name = "hue2", Description = "Second hue (optional)", Default = "-" },
		{ Type = "soulHue", Name = "hue3", Description = "Third hue (optional)", Default = "-" },
	},
}
