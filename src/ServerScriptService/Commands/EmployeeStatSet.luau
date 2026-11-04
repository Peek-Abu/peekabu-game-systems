--!strict
return {
	Name = "employeestatset",
	Aliases = { "stat-set" },
	Description = "Sets a player's employee stat bars for testing (1-5, or reset) and rebuilds them where they stand.",
	Group = "Admins",
	Args = {
		{
			Type = "string",
			Name = "stat",
			Description = "speed, stamina, strength, suction, quiet, or all",
		},
		{ Type = "string", Name = "bars", Description = "1 to 5, or reset (the employee's own)" },
		{ Type = "player", Name = "target", Description = "The player (default: you)", Optional = true },
	},
}
