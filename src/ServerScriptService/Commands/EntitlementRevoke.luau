--!strict
return {
	Name = "entitlementrevoke",
	Aliases = {},
	Description = "Revokes an entitlement (category and id) for a player.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player" },
		{ Type = "string", Name = "category", Description = "The entitlement category (e.g. suit)" },
		{ Type = "string", Name = "id", Description = "The entitlement id within the category" },
	},
}
