--!strict
return {
	Name = "cosmeticbundlegrant",
	Aliases = { "bundlegrant" },
	Description = "Unlocks every item in a cosmetic bundle for a player (the items they own stay owned).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to unlock it for" },
		{ Type = "string", Name = "id", Description = "A CosmeticBundleRegistry id, e.g. Bundle.PJCappy" },
	},
}
