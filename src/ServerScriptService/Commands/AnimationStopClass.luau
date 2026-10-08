--!strict
return {
	Name = "animationstopclass",
	Aliases = { "anim-stop-class" },
	Description = "Ends every attack-class action granted on a player's character. Only 'attack' is actionable — 'protected' and 'ambient' are refused by design.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player whose character is bulk-stopped" },
		{ Type = "string", Name = "class", Description = "attack | protected | ambient (only attack acts)" },
	},
}
