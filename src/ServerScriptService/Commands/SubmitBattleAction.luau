--!strict
--[=[
	Cmdr command definition for submitting battle actions.
	@class SubmitBattleActionDefinition
]=]

return {
	Name = "battleaction",
	Aliases = { "action", "move" },
	Description = "Submit a battle action for a player (testing)",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Player to submit action for",
		},
		{
			Type = "string",
			Name = "Move Name",
			Description = "Name of the move (Strike, Thunderbolt, etc.)",
		},
		{
			Type = "integer",
			Name = "Target Index",
			Description = "Index of target (1-based, optional)",
			Optional = true,
		},
	},
}
