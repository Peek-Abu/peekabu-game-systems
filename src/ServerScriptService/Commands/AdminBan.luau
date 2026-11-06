--!strict
return {
	Name = "adminban",
	Aliases = {},
	Description = "Bans a user id from every place of Odd Hours (Roblox Ban API, alts included). Days 0 = permanent. The reason is shown to them.",
	Group = "Admins",
	Args = {
		{ Type = "integer", Name = "userId", Description = "The user id (works for players who are offline)" },
		{ Type = "integer", Name = "days", Description = "How many days; 0 = permanent" },
		{ Type = "string", Name = "reason", Description = "Shown to the banned player" },
	},
}
