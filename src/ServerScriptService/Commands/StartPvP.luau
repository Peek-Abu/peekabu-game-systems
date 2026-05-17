--!strict
--[=[
	Cmdr command definition for starting a PvP battle using each player's selected character.
	@class StartPvPDefinition
]=]

return {
	Name = "pvp",
	Aliases = { "challenge" },
	Description = "Start a PvP battle using each player's currently selected character. Usage: pvp <p1> <p2> [level]",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "Player 1",
			Description = "First player (must have selected a character via the UI)",
		},
		{
			Type = "player",
			Name = "Player 2",
			Description = "Second player (must have selected a character via the UI)",
		},
		{
			Type = "number",
			Name = "Level",
			Description = "Character level (defaults to 50)",
			Default = 50,
			Optional = true,
		},
	},
}
