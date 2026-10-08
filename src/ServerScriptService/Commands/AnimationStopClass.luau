--!strict
return {
	Name = "animationstopclass",
	Aliases = { "anim-stop-class" },
	Description = "Ends every attack-class action granted on a player's body. Only 'attack' is actionable — 'protected' and 'ambient' are refused by design.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player whose body is bulk-stopped" },
		{ Type = "string", Name = "class", Description = "attack | protected | ambient (only attack acts)" },
	},
}
