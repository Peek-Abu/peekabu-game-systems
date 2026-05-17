--!strict
--[=[
	Cmdr command definition for morphing a player into a character model.
	@class MorphCharacterDefinition
]=]

return {
	Name = "morph",
	Aliases = { "setchar", "character" },
	Description = "Morph a player into a character model. Usage: morph <player> <characterId>",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Player to morph",
		},
		{
			Type = "string",
			Name = "Character",
			Description = "Character ID (GOKU, NARUTO, LUFFY, ICHIGO, GOJO, NATSU, ALL_MIGHT, RIMURU)",
		},
	},
}
