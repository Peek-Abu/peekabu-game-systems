--!strict
return {
	Name = "customizationunlockcosmetic",
	Aliases = {},
	Description = "Grants an account-wide unlock for a lockable cosmetic (free cosmetics need no unlock).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to grant the unlock to" },
		{ Type = "string", Name = "category", Description = "hair | eyebrows | eyelashes | accessory" },
		{ Type = "string", Name = "id", Description = "The lockable cosmetic id (e.g. WizardHat)" },
	},
}
