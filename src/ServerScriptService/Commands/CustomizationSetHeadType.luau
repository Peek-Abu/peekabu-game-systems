--!strict
return {
	Name = "customizationsetheadtype",
	Aliases = {},
	Description = "Sets a player's head mode (which face the rig shows).",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player to change" },
		-- The `headType` enum derives from CustomizationCosmeticRegistry, so this autocompletes and rejects an
		-- unknown mode at the Cmdr boundary rather than only in the service.
		{ Type = "headType", Name = "headType", Description = "Which head mode the rig shows" },
	},
}
