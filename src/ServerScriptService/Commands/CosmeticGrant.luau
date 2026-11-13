--!strict
return {
	Name = "cosmeticgrant",
	Aliases = {},
	Description = "Unlocks one cosmetic (employee, skin, vacuum, idle, emote or sticker pack) for a player; bundlegrant unlocks a bundle.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to unlock it for" },
		{ Type = "string", Name = "id", Description = "A CosmeticRegistry id, e.g. Cappy, Cappy.PJ, CozyPack" },
	},
}
