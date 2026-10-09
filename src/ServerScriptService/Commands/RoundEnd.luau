--!strict
return {
	Name = "roundend",
	Aliases = {},
	Description = "Ends the running round with an outcome.",
	Group = "Admins",
	Args = {
		{ Type = "string", Name = "outcome", Description = "The outcome to end with (e.g. quota, survived)" },
	},
}
