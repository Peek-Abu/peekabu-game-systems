--!strict
return {
	Name = "occupantstage",
	Aliases = { "harlow" },
	Description = "Filming: stage Mr. Harlow. freeze, free, come (walks to you), rush (runs to you), here (moved to you), calm (ignores everyone for a bit), chase <player>.",
	Group = "Admins",
	Args = {
		{ Type = "string", Name = "action", Description = "freeze, free, come, rush, here, calm or chase" },
		{ Type = "player", Name = "player", Description = "Who he chases (chase only)", Optional = true },
	},
}
