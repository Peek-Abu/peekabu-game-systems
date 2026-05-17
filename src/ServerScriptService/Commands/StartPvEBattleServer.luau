--!strict
--[=[
	Admin command to start a PvE battle for a player.
	Usage: startpve <player> <characterId> [enemyCharacterId] [level]
	
	@class StartPvEBattleCommand
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local BattleServiceServer = require(ServerScriptService.Services.BattleService.BattleServiceServer)
local CharacterDefinitions = require(ServerScriptService.Modules.Battle.Characters.CharacterDefinitions)

return function(_context, player: Player, characterId: string, enemyCharacterId: string?, level: number?)
	if not player then
		return "Error: Player must be specified"
	end
	
	if not characterId then
		local allIds = CharacterDefinitions.getAllCharacterIds()
		return `Error: Character must be specified. Available: {table.concat(allIds, ", ")}`
	end
	
	-- Normalize to uppercase
	characterId = string.upper(characterId)
	local enemyId = string.upper(enemyCharacterId or "NATSU")
	local battleLevel = level or 50
	
	-- Validate character IDs
	if not CharacterDefinitions.getCharacterById(characterId) then
		local allIds = CharacterDefinitions.getAllCharacterIds()
		return `Error: Unknown character "{characterId}". Available: {table.concat(allIds, ", ")}`
	end
	if not CharacterDefinitions.getCharacterById(enemyId) then
		local allIds = CharacterDefinitions.getAllCharacterIds()
		return `Error: Unknown enemy character "{enemyId}". Available: {table.concat(allIds, ", ")}`
	end
	
	-- Start a PvE battle
	local session = BattleServiceServer:startBattle(player, {
		characterId = characterId,
		enemyCharacterId = enemyId,
		level = battleLevel,
	})
	
	if session then
		local charDef = CharacterDefinitions.getCharacterById(characterId)
		local enemyDef = CharacterDefinitions.getCharacterById(enemyId)
		return `PvE battle started: {player.Name} as {charDef.name} (Lv{battleLevel}) vs {enemyDef.name} (Lv{battleLevel})!`
	else
		return "Error: Failed to start battle"
	end
end
