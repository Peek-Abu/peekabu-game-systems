--!strict
return {
	Name = "animationplay",
	Aliases = { "anim-play" },
	Description = "Grants a replicated action on a player's body: the owner and every viewer play it in sync (character replication R3).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player whose body plays it" },
		{
			Type = "string",
			Name = "id",
			Description = "A replicable registry action (e.g. testleap, testguard, testpose)",
		},
		{
			Type = "number",
			Name = "speed",
			Description = "Playback speed multiplier (clamped to 0.25-4)",
			Default = 1,
		},
		{
			Type = "number",
			Name = "variant",
			Description = "Which clip: 0 = the entry's own, k = its k-th variant (omit and the server picks)",
			Optional = true,
		},
	},
}
