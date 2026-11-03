--!strict
return {
	Name = "abilitynocooldown",
	Aliases = { "ability-nocd" },
	Description = "Turns no-cooldown mode on or off for a player's ability (you, when no player is named): every use is ready again at once.",
	Group = "Admins",
	Args = {
		{ Type = "boolean", Name = "on", Description = "true: no cooldown; false: the normal cooldown" },
		{ Type = "player", Name = "target", Description = "The player (default: you)", Optional = true },
	},
}
