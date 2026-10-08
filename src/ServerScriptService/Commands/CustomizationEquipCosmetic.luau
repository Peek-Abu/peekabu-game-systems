--!strict
return {
	Name = "customizationequipcosmetic",
	Aliases = {},
	Description = "Equips a cosmetic on a player's active character. Use category 'accessory' with a slot index; every other category (hair/eyebrows/eyelashes/shoes) is a single selection and ignores the slot.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to equip the cosmetic for" },
		{ Type = "string", Name = "category", Description = "hair | eyebrows | eyelashes | shoes | accessory" },
		{ Type = "string", Name = "id", Description = "The cosmetic id (e.g. Hair2, WizardHat)" },
		{
			Type = "integer",
			Name = "slot",
			Description = "Accessory slot (1-3); ignored for non-accessory categories",
			Default = 1,
		},
	},
}
