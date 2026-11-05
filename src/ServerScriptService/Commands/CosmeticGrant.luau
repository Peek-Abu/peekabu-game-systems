--!strict
return {
	Name = "cosmeticgrant",
	Aliases = {},
	Description = "Unlocks a cosmetic (employee, skin, idle, emote or sticker pack) and its bundle for a player.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to unlock it for" },
		{ Type = "string", Name = "id", Description = "A CosmeticRegistry id, e.g. Cappy, Cappy.PJ, CozyPack" },
	},
}
