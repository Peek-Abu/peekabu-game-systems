--!strict
--[=[
	Cmdr command definition for starting PvE battles.
	@class StartPvEBattleDefinition
]=]

return {
	Name = "startpve",
	Aliases = { "pve", "enemy" },
	Description = "Start a PvE battle against an enemy. Usage: startpve <player> <characterId> [enemyCharacterId] [level]",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "Player",
			Description = "Player to start the battle for",
		},
		{
			Type = "string",
			Name = "Character",
			Description = "Character to play as (GOKU, NARUTO, LUFFY, ICHIGO, GOJO, NATSU, ALL_MIGHT, RIMURU)",
		},
		{
			Type = "string",
			Name = "Enemy Character",
			Description = "Enemy character (defaults to NATSU)",
			Default = "NATSU",
			Optional = true,
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
