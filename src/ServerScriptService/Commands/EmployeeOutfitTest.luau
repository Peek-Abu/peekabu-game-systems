--!strict
return {
	Name = "employeeoutfittest",
	Aliases = { "outfit-test" },
	Description = "Test only: fits a skinned outfit from Assets.CleanupCrew.Outfits onto a player's current character "
		.. "(over the skin they wear; a respawn or skin change puts the skin's own outfit back).",
	Group = "Admins",
	Args = {
		{ Type = "string", Name = "outfit", Description = "The outfit Model's name, e.g. PricklesShowstopperTails" },
		{ Type = "player", Name = "target", Description = "The player (default: you)", Optional = true },
	},
}
