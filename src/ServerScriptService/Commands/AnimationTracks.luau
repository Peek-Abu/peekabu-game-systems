--!strict
return {
	Name = "animationtracks",
	Aliases = { "anim-tracks" },
	Description = "Asks a player's client to log its live animation bookkeeping (playback state lives with the owner; read it in the client log or the F4 Animations panel).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player whose client reports its tracks" },
	},
}
