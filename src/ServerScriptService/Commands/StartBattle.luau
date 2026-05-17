--!strict
--[=[
	Cmdr command definition for starting test battles.
	@class StartBattleDefinition
]=]

return {
	Name = "startbattle",
	Aliases = { "battle" },
	Description = "Start a battle between two players. Usage: startbattle <p1> <p2> <char1> <char2> [level]",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "Player 1",
			Description = "First player in the battle",
		},
		{
			Type = "player",
			Name = "Player 2",
			Description = "Second player in the battle",
		},
		{
			Type = "string",
			Name = "Character 1",
			Description = "Character for Player 1 (GOKU, NARUTO, LUFFY, etc.)",
		},
		{
			Type = "string",
			Name = "Character 2",
			Description = "Character for Player 2 (GOKU, NARUTO, LUFFY, etc.)",
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
