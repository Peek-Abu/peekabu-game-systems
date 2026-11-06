--!strict
return {
	Name = "adminunban",
	Aliases = {},
	Description = "Lifts a ban made with adminban (Roblox Ban API) from every place of Odd Hours.",
	Group = "Admins",
	Args = {
		{ Type = "integer", Name = "userId", Description = "The user id" },
	},
}
