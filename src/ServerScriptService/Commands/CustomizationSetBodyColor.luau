--!strict
return {
	Name = "customizationsetbodycolor",
	Aliases = {},
	Description = "Sets one body-color channel on a player's active character (free RGB, 0-255).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to recolor" },
		{ Type = "string", Name = "channel", Description = "color1 | color2 | skin | belt | eye | rope" },
		{ Type = "integer", Name = "r", Description = "Red (0-255)" },
		{ Type = "integer", Name = "g", Description = "Green (0-255)" },
		{ Type = "integer", Name = "b", Description = "Blue (0-255)" },
	},
}
