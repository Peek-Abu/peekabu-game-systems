--!strict
return {
	Name = "dailyrewardreset",
	Aliases = {},
	Description = "Clears a player's daily reward streak so today's reward can be claimed again.",
	Group = "Admins",
	Args = {
		{ Type = "player", Name = "target", Description = "The player" },
	},
}
