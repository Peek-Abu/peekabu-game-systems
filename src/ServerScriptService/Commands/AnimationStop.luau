--!strict
return {
	Name = "animationstop",
	Aliases = { "anim-stop" },
	Description = "Ends a granted action on a player's character early, by action id or by layer (full | upper | overlay).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player whose character stops it" },
		{ Type = "string", Name = "idOrLayer", Description = "A replicable action id, or a layer name" },
	},
}
