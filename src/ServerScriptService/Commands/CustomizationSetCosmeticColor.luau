--!strict
return {
	Name = "customizationsetcosmeticcolor",
	Aliases = {},
	Description = "Recolours one colour channel of an EQUIPPED cosmetic (free RGB, 0-255). Body parts use customizationsetbodycolor instead.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to recolour" },
		{ Type = "string", Name = "category", Description = "hair | eyebrows | eyelashes | shoes | accessory" },
		{ Type = "integer", Name = "r", Description = "Red (0-255)" },
		{ Type = "integer", Name = "g", Description = "Green (0-255)" },
		{ Type = "integer", Name = "b", Description = "Blue (0-255)" },
		-- Which of the cosmetic's OWN colour channels to set. Most cosmetics declare one; the validator
		-- refuses a channel the cosmetic does not have, which is also how you discover its real count.
		{
			Type = "integer",
			Name = "channel",
			Description = "Colour channel on that cosmetic (default 1)",
			Default = 1,
		},
		{ Type = "integer", Name = "slot", Description = "Accessory slot (1-3); ignored otherwise", Default = 1 },
	},
}
